import XCTest
@testable import RTWhisperLib

final class TextInjectorTests: XCTestCase {

    // MARK: - Initialization Tests

    func testTextInjectorCanBeInitialized() {
        let injector = TextInjector()
        XCTAssertNotNil(injector)
    }

    // MARK: - Permission Check Tests

    func testHasAccessibilityPermissionReturnsBool() {
        // This test verifies the method exists and returns a boolean
        // The actual value depends on system state
        let hasPermission = TextInjector.hasAccessibilityPermission()
        XCTAssertTrue(hasPermission == true || hasPermission == false)
    }

    // MARK: - Error Type Tests

    func testTextInjectorErrorDescriptions() {
        let accessibilityError = TextInjectorError.accessibilityNotGranted
        XCTAssertEqual(accessibilityError.localizedDescription, "Accessibility permission not granted")

        let clipboardError = TextInjectorError.clipboardWriteFailed
        XCTAssertEqual(clipboardError.localizedDescription, "Failed to write to clipboard")

        let keySimError = TextInjectorError.keySimulationFailed
        XCTAssertEqual(keySimError.localizedDescription, "Failed to simulate keyboard input")
    }
}
