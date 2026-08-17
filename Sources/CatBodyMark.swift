import CoreGraphics

/// CatGPT 的猫主体与面部线条。
///
/// 图形不包含背景，宿主可根据外观为主体与面部线条分别着色。
enum CatBodyMark {
    struct FacialFeatures {
        let mouth: CGPath
        let mouthStem: CGPath
        let whiskers: CGPath
    }

    /// AppKit 绘图使用左下角坐标原点。
    static func appKitPath(in rect: CGRect) -> CGPath {
        makePath(in: rect) { y in
            rect.minY + (100 - y) / 100 * rect.height
        }
    }

    /// SwiftUI Canvas 使用左上角坐标原点。
    static func swiftUIPath(in rect: CGRect) -> CGPath {
        makePath(in: rect) { y in
            rect.minY + y / 100 * rect.height
        }
    }

    static func appKitFacialFeatures(in rect: CGRect) -> FacialFeatures {
        makeFacialFeatures(in: rect) { y in
            rect.minY + (100 - y) / 100 * rect.height
        }
    }

    static func swiftUIFacialFeatures(in rect: CGRect) -> FacialFeatures {
        makeFacialFeatures(in: rect) { y in
            rect.minY + y / 100 * rect.height
        }
    }

    private static func makePath(
        in rect: CGRect,
        yPosition: (CGFloat) -> CGFloat
    ) -> CGPath {
        let path = CGMutablePath()

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(
                x: rect.minX + x / 100 * rect.width,
                y: yPosition(y)
            )
        }

        // y = 97 留出下缘，确保剪影在任何尺寸下都不越界。
        path.move(to: point(15, 97))
        path.addLine(to: point(20, 35))
        path.addLine(to: point(38, 60))
        path.addQuadCurve(to: point(62, 60), control: point(50, 52))
        path.addLine(to: point(80, 35))
        path.addLine(to: point(85, 97))
        path.closeSubpath()

        return path
    }

    private static func makeFacialFeatures(
        in rect: CGRect,
        yPosition: (CGFloat) -> CGFloat
    ) -> FacialFeatures {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(
                x: rect.minX + x / 100 * rect.width,
                y: yPosition(y)
            )
        }

        let mouth = CGMutablePath()
        mouth.move(to: point(46, 76))
        mouth.addQuadCurve(to: point(54, 76), control: point(50, 79))

        let mouthStem = CGMutablePath()
        mouthStem.move(to: point(50, 79))
        mouthStem.addLine(to: point(50, 82))

        let whiskers = CGMutablePath()
        whiskers.move(to: point(24, 72))
        whiskers.addLine(to: point(41, 75))
        whiskers.move(to: point(22, 78))
        whiskers.addLine(to: point(41, 78))
        whiskers.move(to: point(76, 72))
        whiskers.addLine(to: point(59, 75))
        whiskers.move(to: point(78, 78))
        whiskers.addLine(to: point(59, 78))

        return FacialFeatures(mouth: mouth, mouthStem: mouthStem, whiskers: whiskers)
    }
}
