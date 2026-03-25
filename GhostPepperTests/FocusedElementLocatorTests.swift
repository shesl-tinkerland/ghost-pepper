import CoreGraphics
import XCTest
@testable import GhostPepper

final class FocusedElementLocatorTests: XCTestCase {
    func testWindowReferenceReadsSwiftDictionaryBounds() {
        let locator = FocusedElementLocator()
        let windowList: [[String: Any]] = [[
            kCGWindowOwnerPID as String: NSNumber(value: 42),
            kCGWindowLayer as String: 0,
            kCGWindowAlpha as String: 1.0,
            kCGWindowNumber as String: NSNumber(value: 99),
            kCGWindowBounds as String: [
                "X": 10,
                "Y": 20,
                "Width": 300,
                "Height": 200
            ]
        ]]

        let reference = locator.windowReference(in: windowList, for: 42)

        XCTAssertEqual(reference?.windowID, 99)
        XCTAssertEqual(reference?.frame, CGRect(x: 10, y: 20, width: 300, height: 200))
    }

    func testWindowReferenceIgnoresUnsupportedBoundsValue() {
        let locator = FocusedElementLocator()
        let windowList: [[String: Any]] = [[
            kCGWindowOwnerPID as String: NSNumber(value: 42),
            kCGWindowLayer as String: 0,
            kCGWindowAlpha as String: 1.0,
            kCGWindowNumber as String: NSNumber(value: 99),
            kCGWindowBounds as String: "not a bounds dictionary"
        ]]

        XCTAssertNil(locator.windowReference(in: windowList, for: 42))
    }
}
