import XCTest
@testable import HeadBird

final class ShortcutActionExecutorTests: XCTestCase {
    func testBuildsEncodedShortcutURL() async {
        await MainActor.run {
            let executor = ShortcutActionExecutor()

            let url = executor.makeShortcutURL(name: "Dark Mode Toggle")

            XCTAssertEqual(url?.absoluteString, "shortcuts://run-shortcut?name=Dark%20Mode%20Toggle")
        }
    }

    func testRejectsEmptyShortcutName() async {
        await MainActor.run {
            let executor = ShortcutActionExecutor()

            let result = executor.execute(shortcutName: "   ")

            XCTAssertEqual(result, .failure("Shortcut name is empty."))
        }
    }
}
