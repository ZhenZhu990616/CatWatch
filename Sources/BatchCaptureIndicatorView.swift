import AppKit

final class BatchCaptureIndicatorView: NSView {
    private let shapeLayer = CAShapeLayer()
    private var tintColor = NSColor.labelColor
    private var tintOpacity: CGFloat = 1
    private var starSize: CGFloat = 7
    private(set) var count = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.addSublayer(shapeLayer)
        shapeLayer.fillRule = .nonZero
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("已缓存 0 张截图")
    }

    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }

    func configure(color: NSColor, opacity: Double, starSize: CGFloat) {
        tintColor = color
        tintOpacity = CGFloat(min(1, max(0, opacity)))
        self.starSize = max(4, starSize)
        redrawLayer()
    }

    func setCount(_ count: Int) {
        self.count = min(max(count, 0), BatchCaptureQueue.maximumImageCount)
        setAccessibilityLabel("已缓存 \(self.count) 张截图")
        invalidateIntrinsicContentSize()
        needsLayout = true
        redrawLayer()
    }

    override var intrinsicContentSize: NSSize {
        guard count > 0 else { return .zero }
        let spacing = max(3, starSize * 0.45)
        return NSSize(width: CGFloat(count) * starSize + CGFloat(count - 1) * spacing, height: starSize)
    }

    override func layout() {
        super.layout()
        redrawLayer()
    }

    private func redrawLayer() {
        shapeLayer.fillColor = tintColor.withAlphaComponent(tintOpacity).cgColor
        shapeLayer.frame = bounds
        shapeLayer.path = starPath()
    }

    private func starPath() -> CGPath {
        let path = CGMutablePath()
        guard count > 0 else { return path }
        let spacing = max(3, starSize * 0.45)
        for index in 0..<count {
            let center = CGPoint(x: starSize / 2 + CGFloat(index) * (starSize + spacing), y: starSize / 2)
            for pointIndex in 0..<12 {
                let angle = -CGFloat.pi / 2 + CGFloat(pointIndex) * CGFloat.pi / 6
                let radius = pointIndex.isMultiple(of: 2) ? starSize / 2 : starSize / 4
                let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                if pointIndex == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
        }
        return path
    }
}
