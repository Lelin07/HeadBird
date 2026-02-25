import Foundation
import UserNotifications

@MainActor
protocol PromptTargetBannerNotifying {
    func requestAuthorizationIfNeeded()
    func authorizationStatus() async -> UNAuthorizationStatus
    func notifyTargetReady(promptName: String)
    func notifyPromptDetected(promptName: String)
    func notifyTargetLost(reason: String)
}

@MainActor
protocol PromptTargetNotificationDriving {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func postNotification(title: String, body: String) async throws
}

private struct LivePromptTargetNotificationDriver: PromptTargetNotificationDriving {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await center.requestAuthorization(options: options)
    }

    func postNotification(title: String, body: String) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        let identifier = "HeadBird.PromptTarget.\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        try await center.add(request)
    }
}

@MainActor
final class PromptTargetBannerNotifier: PromptTargetBannerNotifying {
    private let driver: PromptTargetNotificationDriving
    private var hasRequestedAuthorization = false

    init(driver: PromptTargetNotificationDriving = LivePromptTargetNotificationDriver()) {
        self.driver = driver
    }

    func requestAuthorizationIfNeeded() {
        guard !hasRequestedAuthorization else { return }
        hasRequestedAuthorization = true

        Task { @MainActor in
            let status = await driver.authorizationStatus()
            guard status == .notDetermined else { return }
            _ = try? await driver.requestAuthorization(options: [.alert, .sound])
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await driver.authorizationStatus()
    }

    func notifyTargetReady(promptName: String) {
        let trimmed = promptName.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = trimmed.isEmpty ? "Unknown prompt" : trimmed
        postBanner(body: "Prompt target ready: \(label)")
    }

    func notifyPromptDetected(promptName: String) {
        let trimmed = promptName.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = trimmed.isEmpty ? "Unknown prompt" : trimmed
        postBanner(body: "Prompt detected: \(label)")
    }

    func notifyTargetLost(reason: String) {
        postBanner(body: "Prompt target lost: \(reason)")
    }

    private func postBanner(body: String) {
        Task { @MainActor in
            let status = await driver.authorizationStatus()
            guard canPostNotifications(status: status) else { return }
            try? await driver.postNotification(title: "HeadBird", body: body)
        }
    }

    private func canPostNotifications(status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional:
            return true
        case .notDetermined, .denied:
            return false
        @unknown default:
            return false
        }
    }
}
