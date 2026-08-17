import XCTest
@testable import CatGPT

final class CatBodyMarkTests: XCTestCase {
    func testSwiftUIPathUsesTopLeftCoordinateSystem() {
        let path = CatBodyMark.swiftUIPath(in: CGRect(x: 0, y: 0, width: 100, height: 100))

        XCTAssertEqual(path.boundingBox.minY, 35, accuracy: 0.001)
        XCTAssertEqual(path.boundingBox.maxY, 97, accuracy: 0.001)
    }

    func testAppKitPathUsesBottomLeftCoordinateSystem() {
        let path = CatBodyMark.appKitPath(in: CGRect(x: 0, y: 0, width: 100, height: 100))

        XCTAssertEqual(path.boundingBox.minY, 3, accuracy: 0.001)
        XCTAssertEqual(path.boundingBox.maxY, 65, accuracy: 0.001)
    }
}
