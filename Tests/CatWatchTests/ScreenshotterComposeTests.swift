import AppKit
import XCTest
@testable import CatWatch

final class ScreenshotterComposeTests: XCTestCase {
    func testComposeKeepsUnionAndIgnoresMissingImages() throws {
        let first = try makeImage(width: 4, height: 4, color: .red)
        let second = try makeImage(width: 2, height: 2, color: .blue)

        let result = try Screenshotter.compose([
            (frame: CGRect(x: 10, y: 20, width: 2, height: 2), image: first),
            (frame: CGRect(x: 12, y: 22, width: 1, height: 1), image: nil),
            (frame: CGRect(x: 13, y: 24, width: 1, height: 1), image: second)
        ])

        XCTAssertEqual(result.union, CGRect(x: 10, y: 20, width: 4, height: 5))
        XCTAssertEqual(result.image.width, 8)
        XCTAssertEqual(result.image.height, 10)
    }

    private func makeImage(width: Int, height: Int, color: NSColor) throws -> CGImage {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bitmapFormat: [],
            bytesPerRow: width * 4,
            bitsPerPixel: 32
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        color.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()
        NSGraphicsContext.restoreGraphicsState()
        return rep.cgImage!
    }
}
