import Foundation

/// Timer per tracciare il tempo di completamento dei task utente
class TaskTimer {
    static let shared = TaskTimer()

    private var taskStartTimes: [String: Date] = [:]
    private var taskAttempts: [String: Int] = [:]

    private init() {}

    // MARK: - Task Tracking

    func startTask(_ taskName: String, screen: String = "") {
        taskStartTimes[taskName] = Date()
        taskAttempts[taskName] = (taskAttempts[taskName] ?? 0) + 1

        Task {
            await AnalyticsManager.shared.track(
                .taskStarted(task: taskName, screen: screen)
            )
        }
    }

    func completeTask(_ taskName: String, success: Bool = true) {
        guard let startTime = taskStartTimes[taskName] else {
            return
        }

        let duration = Date().timeIntervalSince(startTime)
        let attempts = taskAttempts[taskName] ?? 1

        Task {
            await AnalyticsManager.shared.track(
                .taskCompleted(
                    task: taskName,
                    duration: duration,
                    success: success,
                    attempts: attempts
                )
            )
        }

        // Clean up
        taskStartTimes.removeValue(forKey: taskName)
        if success {
            taskAttempts.removeValue(forKey: taskName)
        }
    }

    func cancelTask(_ taskName: String) {
        taskStartTimes.removeValue(forKey: taskName)
        // Keep attempts count for next try
    }

    // MARK: - Convenience Methods

    func measureTask<T>(
        _ taskName: String,
        screen: String = "",
        execute: () async throws -> T
    ) async rethrows -> T {
        startTask(taskName, screen: screen)

        do {
            let result = try await execute()
            completeTask(taskName, success: true)
            return result
        } catch {
            completeTask(taskName, success: false)
            throw error
        }
    }
}
