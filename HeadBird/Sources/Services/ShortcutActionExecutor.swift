import AppKit
import Foundation

final class ShortcutActionExecutor {
    func execute(shortcutName: String) -> GestureActionResult {
        let trimmed = shortcutName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure("Shortcut name is empty.")
        }

        guard let url = makeShortcutURL(name: trimmed) else {
            return .failure("Invalid shortcut name.")
        }

        guard NSWorkspace.shared.open(url) else {
            return .failure("Failed to run shortcut '\(trimmed)'.")
        }

        return .success("Ran shortcut '\(trimmed)'.")
    }

    func makeShortcutURL(name: String) -> URL? {
        var components = URLComponents()
        components.scheme = "shortcuts"
        components.host = "run-shortcut"
        components.queryItems = [
            URLQueryItem(name: "name", value: name)
        ]
        return components.url
    }
}
