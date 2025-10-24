import Foundation
import UIKit

/// Manager per tracciare le sessioni utente
class SessionManager {
    static let shared = SessionManager()

    private var sessionId: String?
    private var sessionStart: Date?
    private var screensVisited: Set<String> = []
    private var actionsPerformed: Int = 0

    private init() {
        setupNotifications()
    }

    // MARK: - Setup

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }

    // MARK: - Session Lifecycle

    @objc private func applicationDidBecomeActive() {
        startSession()
    }

    @objc private func applicationWillResignActive() {
        endSession()
    }

    @objc private func applicationWillTerminate() {
        endSession()
    }

    func startSession() {
        sessionId = UUID().uuidString
        sessionStart = Date()
        screensVisited.removeAll()
        actionsPerformed = 0

        Task {
            await AnalyticsManager.shared.track(
                .sessionStarted(sessionId: sessionId ?? "unknown")
            )
        }
    }

    func endSession() {
        guard let id = sessionId, let start = sessionStart else { return }

        let duration = Date().timeIntervalSince(start)

        Task {
            await AnalyticsManager.shared.track(
                .sessionEnded(
                    sessionId: id,
                    duration: duration,
                    screensVisited: screensVisited.count,
                    actions: actionsPerformed
                )
            )
        }

        sessionId = nil
        sessionStart = nil
        screensVisited.removeAll()
        actionsPerformed = 0
    }

    // MARK: - Tracking

    func trackScreenView(_ screenName: String) {
        screensVisited.insert(screenName)

        Task {
            await AnalyticsManager.shared.track(
                .screenViewed(name: screenName)
            )
        }
    }

    func trackAction() {
        actionsPerformed += 1
    }

    // MARK: - Getters

    func getCurrentSessionId() -> String? {
        return sessionId
    }

    func getSessionDuration() -> TimeInterval? {
        guard let start = sessionStart else { return nil }
        return Date().timeIntervalSince(start)
    }
}
