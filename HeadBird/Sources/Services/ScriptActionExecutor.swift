import Foundation

final class ScriptActionExecutor {
    func executeAppleScript(source: String) -> GestureActionResult {
        let script = NSAppleScript(source: source)
        var error: NSDictionary?
        let result = script?.executeAndReturnError(&error)

        if result != nil {
            return .success("AppleScript executed.")
        }

        if let error,
           let message = error[NSAppleScript.errorMessage] as? String {
            return .failure("AppleScript failed: \(message)")
        }

        return .failure("AppleScript failed.")
    }
}
