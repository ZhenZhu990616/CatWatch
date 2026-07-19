import CoreGraphics
import Foundation
import ScreenCaptureKit

/// macOS 14+ 的 ScreenCaptureKit 截屏路径。
/// 相比 CGDisplayCreateImage（macOS 14 起弃用）：走 GPU 管线更快、
/// 直接以像素分辨率输出，并能用 SCContentFilter 排除自家窗口
/// （结果面板、框选蒙层），从根上消除"先隐藏窗口再定时等待"的竞态。
@available(macOS 14.0, *)
enum SCKScreenshotter {
    static func captureAllDisplaysImage() async throws -> (image: CGImage, union: CGRect) {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            throw AppError.screenshot("无法枚举屏幕内容：\(error.localizedDescription)")
        }

        guard !content.displays.isEmpty else {
            throw AppError.screenshot("没有找到可用显示器。")
        }

        let ownPID = ProcessInfo.processInfo.processIdentifier
        let ownWindows = content.windows.filter { $0.owningApplication?.processID == ownPID }

        var entries: [(frame: CGRect, image: CGImage?)] = []
        for display in content.displays {
            let filter = SCContentFilter(display: display, excludingWindows: ownWindows)

            let configuration = SCStreamConfiguration()
            // 以真实像素分辨率截取，保住 Retina 细节。
            if let mode = CGDisplayCopyDisplayMode(display.displayID) {
                configuration.width = mode.pixelWidth
                configuration.height = mode.pixelHeight
            } else {
                configuration.width = display.width
                configuration.height = display.height
            }
            configuration.captureResolution = .best
            configuration.showsCursor = false

            // 单个显示器失败（如刚断开）不终结整次截图，但 frame 仍要
            // 参与合成的 union 计算，保证裁剪几何与全屏幕 union 一致。
            let image = try? await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
            entries.append((CGDisplayBounds(display.displayID), image))
        }

        return try Screenshotter.compose(entries)
    }
}
