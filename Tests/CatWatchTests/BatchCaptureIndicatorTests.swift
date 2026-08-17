import AppKit
import XCTest
@testable import CatWatch

final class BatchCaptureIndicatorTests: XCTestCase {
    @MainActor
    func testIndicatorClampsCountAndExposesAccessibleCount() {
        let view = BatchCaptureIndicatorView(frame: .zero)
        view.configure(color: .labelColor, opacity: 1, starSize: 7)
        view.setCount(99)

        XCTAssertEqual(view.count, BatchCaptureQueue.maximumImageCount)
        XCTAssertEqual(view.accessibilityLabel(), "已缓存 8 张截图")
        XCTAssertGreaterThan(view.intrinsicContentSize.width, 0)
    }

    @MainActor
    func testZeroCountHasNoVisibleIntrinsicSize() {
        let view = BatchCaptureIndicatorView(frame: .zero)
        view.setCount(0)

        XCTAssertEqual(view.intrinsicContentSize, .zero)
    }
}
