import XCTest
@testable import CatGPT

final class TouchBarResultControllerTests: XCTestCase {
    func testPresentationDoesNotUsePrivateSystemModalAPI() {
        XCTAssertFalse(TouchBarResultController.usesPrivatePresentationAPI)
    }

    func testAvailabilityUsesNoPrivateFrameworkProbe() {
        XCTAssertFalse(TouchBarResultController.usesPrivateAvailabilityProbe)
    }

    func testKnownTouchBarHardwareDetectionExcludesDesktopMacs() {
        XCTAssertTrue(TouchBarResultController.isKnownTouchBarModel("MacBookPro17,1"))
        XCTAssertFalse(TouchBarResultController.isKnownTouchBarModel("MacBookAir10,1"))
        XCTAssertFalse(TouchBarResultController.isKnownTouchBarModel("Macmini9,1"))
    }
}
