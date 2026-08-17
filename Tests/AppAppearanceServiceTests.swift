import XCTest
@testable import FlashForge

@MainActor
final class AppAppearanceServiceTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "AppAppearanceServiceTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultsToSystemAppearance() {
        let service = AppAppearanceService(defaults: defaults)

        XCTAssertEqual(service.current, .system)
    }

    func testPersistsAndAppliesSelectedAppearance() {
        let service = AppAppearanceService(defaults: defaults)
        let window = UIWindow()

        service.set(.dark, on: window)

        XCTAssertEqual(service.current, .dark)
        XCTAssertEqual(window.overrideUserInterfaceStyle, .dark)
    }
}
