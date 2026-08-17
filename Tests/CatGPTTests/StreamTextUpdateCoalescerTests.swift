import XCTest
@testable import CatGPT

@MainActor
final class StreamTextUpdateCoalescerTests: XCTestCase {
    func testRapidDeltasEmitImmediatelyThenCoalesceUntilFlush() {
        let coalescer = StreamTextUpdateCoalescer(interval: 10)
        var emitted: [String] = []

        coalescer.submit("a") { emitted.append($0) }
        coalescer.submit("ab") { emitted.append($0) }
        coalescer.submit("abc") { emitted.append($0) }

        XCTAssertEqual(emitted, ["a"])
        coalescer.flush()
        XCTAssertEqual(emitted, ["a", "abc"])
    }

    func testCancelDropsPendingDelta() {
        let coalescer = StreamTextUpdateCoalescer(interval: 10)
        var emitted: [String] = []

        coalescer.submit("a") { emitted.append($0) }
        coalescer.submit("ab") { emitted.append($0) }
        coalescer.cancel()
        coalescer.flush()

        XCTAssertEqual(emitted, ["a"])
    }
}
