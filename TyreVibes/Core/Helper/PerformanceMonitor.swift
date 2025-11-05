import Foundation
import QuartzCore
import UIKit

/// Monitor per tracciare le performance dell'app (FPS, memoria, etc.)
class PerformanceMonitor {
    static let shared = PerformanceMonitor()

    private var displayLink: CADisplayLink?
    private var frameCount = 0
    private var lastTimestamp: CFTimeInterval = 0
    private var currentScreen: String = ""
    private var isMonitoring = false

    // Sampling: track FPS solo per 10% delle sessioni per ridurre overhead
    private let shouldSample: Bool

    private init() {
        shouldSample = Double.random(in: 0...1) < 0.1 // 10% sampling
    }

    // MARK: - FPS Monitoring

    func startMonitoring(screen: String) {
        guard shouldSample, !isMonitoring else { return }

        currentScreen = screen
        isMonitoring = true
        frameCount = 0
        lastTimestamp = 0

        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkTick))
        displayLink?.add(to: .main, forMode: .common)
    }

    func stopMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
        isMonitoring = false
    }

    @objc private func displayLinkTick(_ displayLink: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = displayLink.timestamp
        }

        frameCount += 1
        let elapsed = displayLink.timestamp - lastTimestamp

        if elapsed >= 1.0 {
            let fps = Double(frameCount) / elapsed

            Task {
                await AnalyticsManager.shared.track(
                    .fpsRecorded(screen: currentScreen, fps: fps)
                )
            }

            frameCount = 0
            lastTimestamp = displayLink.timestamp
        }
    }

    // MARK: - Memory Monitoring

    func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return result == KERN_SUCCESS ? info.resident_size : 0
    }

    // MARK: - Performance Measurement

    @discardableResult
    func measure<T>(
        _ operation: String,
        screen: String = "",
        execute: () async throws -> T
    ) async rethrows -> T {
        let startTime = Date()
        let startMemory = getMemoryUsage()

        defer {
            let duration = Date().timeIntervalSince(startTime)
            let memoryDelta = getMemoryUsage() - startMemory

            #if DEBUG
            print("⏱️ [\(operation)] Duration: \(String(format: "%.2f", duration * 1000))ms, Memory: \(memoryDelta / 1024 / 1024)MB")
            #endif
        }

        return try await execute()
    }
}
