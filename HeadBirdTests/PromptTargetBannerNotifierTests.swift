import UserNotifications
import XCTest
@testable import HeadBird

@MainActor
final class PromptTargetBannerNotifierTests: XCTestCase {
    func testRequestsAuthorizationOnlyOnceWhenUndetermined() async {
        let driver = PromptTargetNotificationDriverMock(status: .notDetermined)
        let notifier = PromptTargetBannerNotifier(driver: driver)

        notifier.requestAuthorizationIfNeeded()
        notifier.requestAuthorizationIfNeeded()
        try? await Task.sleep(for: .milliseconds(50))

        let requestCount = await driver.requestCountValue()
        XCTAssertEqual(requestCount, 1)
    }

    func testNotifyReadyPostsBannerWhenAuthorized() async {
        let driver = PromptTargetNotificationDriverMock(status: .authorized)
        let notifier = PromptTargetBannerNotifier(driver: driver)

        notifier.notifyTargetReady(promptName: "Empty Trash")
        try? await Task.sleep(for: .milliseconds(50))

        let postedBodies = await driver.postedBodiesValue()
        XCTAssertEqual(postedBodies, ["Prompt target ready: Empty Trash"])
    }

    func testNotifyLostDoesNotPostWhenDenied() async {
        let driver = PromptTargetNotificationDriverMock(status: .denied)
        let notifier = PromptTargetBannerNotifier(driver: driver)

        notifier.notifyTargetLost(reason: "No focused prompt container.")
        try? await Task.sleep(for: .milliseconds(50))

        let postedBodies = await driver.postedBodiesValue()
        XCTAssertTrue(postedBodies.isEmpty)
    }

    func testNotifyPromptDetectedPostsBannerWhenAuthorized() async {
        let driver = PromptTargetNotificationDriverMock(status: .authorized)
        let notifier = PromptTargetBannerNotifier(driver: driver)

        notifier.notifyPromptDetected(promptName: "Empty Trash")
        try? await Task.sleep(for: .milliseconds(50))

        let postedBodies = await driver.postedBodiesValue()
        XCTAssertEqual(postedBodies, ["Prompt detected: Empty Trash"])
    }
}

@MainActor
final class PromptTargetNotificationDriverMock: PromptTargetNotificationDriving {
    private(set) var status: UNAuthorizationStatus
    private(set) var requestCount = 0
    private(set) var postedBodies: [String] = []

    init(status: UNAuthorizationStatus) {
        self.status = status
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        status
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestCount += 1
        status = .authorized
        return true
    }

    func postNotification(title: String, body: String) async throws {
        _ = title
        postedBodies.append(body)
    }

    func requestCountValue() -> Int {
        requestCount
    }

    func postedBodiesValue() -> [String] {
        postedBodies
    }
}
