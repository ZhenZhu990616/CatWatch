import AppKit
import CoreGraphics
import Foundation

enum Screenshotter {
    static func hasPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    static func requestPermissionIfNeeded() {
        guard !CGPreflightScreenCaptureAccess() else { return }
        _ = CGRequestScreenCaptureAccess()
    }

    static func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 统一截图入口：macOS 14+ 走 ScreenCaptureKit（GPU 管线、排除自家窗口），
    /// 旧系统回退 CGDisplayCreateImage；重活（截取、合成、编码）都在后台执行。
    /// 输出 JPEG——对视觉模型识别质量几乎无损，但体积比 PNG 小数倍，上传明显提速。
    static func captureImageData(maxEdge: Int, region: CGRect? = nil) async throws -> Data {
        guard CGPreflightScreenCaptureAccess() else {
            throw AppError.screenshot("需要授予 CatWatch 屏幕录制权限。请点击菜单里的“权限”，在系统设置中启用后重新打开应用。")
        }

        // NSScreen 属主线程 API，先在主线程取好 Cocoa 坐标系的屏幕范围。
        let screenUnion = await MainActor.run {
            NSScreen.screens
                .map(\.frame)
                .reduce(CGRect.null) { $0.union($1) }
        }

        var image: CGImage
        let capturedUnion: CGRect
        if #available(macOS 14.0, *) {
            (image, capturedUnion) = try await SCKScreenshotter.captureAllDisplaysImage()
        } else {
            (image, capturedUnion) = try await Task.detached(priority: .userInitiated) {
                try captureAllDisplaysLegacy()
            }.value
        }

        if let region {
            // screenUnion(NSScreen, 主线程预读) 与 capturedUnion(捕获时枚举) 是两次独立
            // 读取；若捕获期间有显示器热插拔/休眠，两者尺寸会不一致，裁剪几何会错位。
            // 宁可失败让用户重试，也不静默送错区域给模型。
            guard abs(screenUnion.width - capturedUnion.width) < 1,
                  abs(screenUnion.height - capturedUnion.height) < 1 else {
                throw AppError.screenshot("截图期间显示器配置发生变化，请重试。")
            }
            image = try crop(image, to: region, screenUnion: screenUnion)
        }

        let finalImage = image
        return try await Task.detached(priority: .userInitiated) {
            try jpegData(from: finalImage, maxEdge: maxEdge)
        }.value
    }

    /// 把各显示器的（点坐标 frame，像素分辨率 image）合成为一张全局大图。
    /// 合成 context 按最大 backing scale 放大，保留 Retina 像素细节——
    /// 这对"给 AI 读屏幕小字"至关重要（缩放比从实际图像推导，
    /// CGDisplayPixelsWide 在 HiDPI 模式下返回的是点数，不可靠）。
    /// image 为 nil 表示该显示器截取失败：它的 frame 仍参与 union 计算
    /// （保证与 crop 用的全屏幕 union 几何一致），画面留空块。
    static func compose(_ entries: [(frame: CGRect, image: CGImage?)]) throws -> (image: CGImage, union: CGRect) {
        guard entries.contains(where: { $0.image != nil }) else {
            throw AppError.screenshot("无法读取任何显示器画面。")
        }

        let union = entries.map(\.frame).reduce(CGRect.null) { $0.union($1) }
        guard !union.isNull, union.width > 0, union.height > 0 else {
            throw AppError.screenshot("无法计算屏幕区域。")
        }

        let maxScale = entries
            .compactMap { entry -> CGFloat? in
                guard let image = entry.image, entry.frame.width > 0 else { return nil }
                return CGFloat(image.width) / entry.frame.width
            }
            .max() ?? 1

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: Int(union.width * maxScale),
                  height: Int(union.height * maxScale),
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw AppError.screenshot("无法创建截图上下文。")
        }

        context.interpolationQuality = .high
        for entry in entries {
            guard let image = entry.image else { continue }
            let destination = CGRect(
                x: (entry.frame.minX - union.minX) * maxScale,
                y: (union.maxY - entry.frame.maxY) * maxScale,
                width: entry.frame.width * maxScale,
                height: entry.frame.height * maxScale
            )
            context.draw(image, in: destination)
        }

        guard let image = context.makeImage() else {
            throw AppError.screenshot("无法渲染截图。")
        }

        return (image, union)
    }

    private static func captureAllDisplaysLegacy() throws -> (image: CGImage, union: CGRect) {
        var displayCount: UInt32 = 0
        var result = CGGetActiveDisplayList(0, nil, &displayCount)
        guard result == .success, displayCount > 0 else {
            throw AppError.screenshot("没有找到可用显示器。")
        }

        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        result = CGGetActiveDisplayList(displayCount, &displays, &displayCount)
        guard result == .success else {
            throw AppError.screenshot("无法读取显示器列表。")
        }

        // 截取失败的显示器保留 frame（image 为 nil），维持 union 几何完整。
        let entries: [(frame: CGRect, image: CGImage?)] = displays.map { display in
            (CGDisplayBounds(display), CGDisplayCreateImage(display))
        }

        return try compose(entries)
    }

    private static func crop(_ image: CGImage, to region: CGRect, screenUnion union: CGRect) throws -> CGImage {
        guard !union.isNull, !union.isEmpty else {
            throw AppError.screenshot("无法计算屏幕区域。")
        }

        let scaleX = CGFloat(image.width) / union.width
        let scaleY = CGFloat(image.height) / union.height
        let pixelRect = CGRect(
            x: (region.minX - union.minX) * scaleX,
            y: (union.maxY - region.maxY) * scaleY,
            width: region.width * scaleX,
            height: region.height * scaleY
        )
        .integral
        .intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))

        guard !pixelRect.isNull, pixelRect.width >= 2, pixelRect.height >= 2,
              let cropped = image.cropping(to: pixelRect) else {
            throw AppError.screenshot("框选区域太小，无法截图。")
        }

        return cropped
    }

    private static func jpegData(from image: CGImage, maxEdge: Int) throws -> Data {
        let scaled = scale(image, maxEdge: maxEdge)
        let bitmap = NSBitmapImageRep(cgImage: scaled)

        guard let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else {
            throw AppError.screenshot("无法将截图编码为 JPEG。")
        }

        return data
    }

    private static func scale(_ image: CGImage, maxEdge: Int) -> CGImage {
        // 最后防线：非法上限（0/负数）直接不缩放，避免产出 1×1 图。
        guard maxEdge > 0 else { return image }

        let width = image.width
        let height = image.height
        let currentMax = max(width, height)

        guard currentMax > maxEdge else { return image }

        let ratio = Double(maxEdge) / Double(currentMax)
        let newWidth = max(1, Int(Double(width) * ratio))
        let newHeight = max(1, Int(Double(height) * ratio))

        guard let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: newWidth,
                  height: newHeight,
                  bitsPerComponent: image.bitsPerComponent,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return image
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        return context.makeImage() ?? image
    }
}
