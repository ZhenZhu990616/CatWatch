#!/usr/bin/env swift
import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: generate-app-icon.swift <output.icns>\n".utf8))
    exit(2)
}

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = output.deletingPathExtension().appendingPathExtension("iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

for (size, name) in sizes {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    drawIcon(in: NSRect(x: 0, y: 0, width: size, height: size), scale: CGFloat(size) / 1024)
    image.unlockFocus()

    guard let data = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: data),
          let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "Icon", code: 1)
    }
    try png.write(to: iconset.appendingPathComponent(name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try process.run()
process.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)

if process.terminationStatus != 0 {
    throw NSError(domain: "iconutil", code: Int(process.terminationStatus))
}

private func drawIcon(in rect: NSRect, scale: CGFloat) {
    let iconRect = rect.insetBy(dx: 34 * scale, dy: 34 * scale)
    let background = NSBezierPath(
        roundedRect: iconRect,
        xRadius: 230 * scale,
        yRadius: 230 * scale
    )
    NSColor.black.setFill()
    background.fill()

    guard let context = NSGraphicsContext.current?.cgContext else { return }
    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(
            x: iconRect.minX + x / 100 * iconRect.width,
            y: iconRect.minY + (100 - y) / 100 * iconRect.height
        )
    }

    let cat = CGMutablePath()
    cat.move(to: point(15, 105))
    cat.addLine(to: point(20, 35))
    cat.addLine(to: point(38, 60))
    cat.addQuadCurve(to: point(62, 60), control: point(50, 52))
    cat.addLine(to: point(80, 35))
    cat.addLine(to: point(85, 105))
    cat.closeSubpath()

    context.setFillColor(NSColor.white.cgColor)
    context.addPath(cat)
    context.fillPath()
}
