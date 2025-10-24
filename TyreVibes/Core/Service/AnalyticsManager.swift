import Foundation
import OSLog

// MARK: - Analytics Event Protocol

protocol AnalyticsEvent {
    var name: String { get }
    var parameters: [String: Any] { get }
    var timestamp: Date { get }
    var userId: String? { get }
}

// MARK: - Supporting Enums

enum AuthMethod: String, Codable {
    case email
    case apple
    case google
    case spid
    case otp
}

enum VehicleAddMethod: String, Codable {
    case scan
    case manual
}

enum TyreAddMethod: String, Codable {
    case manual
    case photo
}

enum AnalysisType: String, Codable {
    case tread
    case surface
    case complete
}

enum PaywallTrigger: String, Codable {
    case featureGate = "feature_gate"
    case onboarding = "onboarding"
    case settings = "settings"
    case postAnalysis = "post_analysis"
}

enum NPSCategory: String, Codable {
    case promoter
    case passive
    case detractor
}

// MARK: - Analytics Manager

actor AnalyticsManager {
    static let shared = AnalyticsManager()

    private var eventQueue: [Event] = []
    private var isEnabled: Bool
    private let batchSize = 20
    private let flushInterval: TimeInterval = 60 // 1 min
    private let networkManager = NetworkManager.shared

    private let logger = Logger(subsystem: "com.tyrevibes.app", category: "Analytics")

    init() {
        isEnabled = FeatureFlags.shared.isAnalyticsEnabled
        startPeriodicFlush()
    }

    // MARK: - Event Tracking

    func track(_ event: Event) {
        guard isEnabled else { return }

        eventQueue.append(event)

        // Log locally for debugging
        #if DEBUG
        logger.info("📊 Analytics: \(event.name) - \(String(describing: event.parameters))")
        #endif

        // Flush if batch size reached
        if eventQueue.count >= batchSize {
            Task {
                await flush()
            }
        }
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    // MARK: - Event Types

    enum Event: AnalyticsEvent {
        // Lifecycle
        case appOpened(timestamp: Date)
        case appLaunched(coldStartTime: TimeInterval)
        case sessionStarted(sessionId: String)
        case sessionEnded(sessionId: String, duration: TimeInterval, screensVisited: Int, actions: Int)

        // Authentication
        case userSignedUp(method: AuthMethod, source: String?)
        case userLoggedIn(method: AuthMethod)
        case userLoggedOut

        // Onboarding
        case onboardingStepViewed(step: Int, timestamp: Date)
        case onboardingCompleted(duration: TimeInterval, stepsViewed: Int)
        case onboardingSkipped(lastStep: Int)

        // Vehicle Management
        case vehicleAddMethodSelected(method: VehicleAddMethod, screen: String)
        case plateDetected(duration: TimeInterval, attempts: Int, confidence: Double)
        case plateScanFailed(reason: String, attempts: Int)
        case vehicleAdded(method: VehicleAddMethod, timeSinceSignup: TimeInterval?)
        case firstVehicleAdded(timeSinceSignup: TimeInterval, method: VehicleAddMethod)
        case vehicleViewed(vehicleId: String)
        case vehicleDeleted(vehicleId: String, vehicleAge: TimeInterval)

        // Tyre Management
        case tyreRegistered(method: TyreAddMethod)
        case tyreAnalysisStarted(type: AnalysisType)
        case tyreAnalysisCompleted(type: AnalysisType, duration: TimeInterval, success: Bool, imageSize: CGSize?)
        case tyreAnalysisFailed(type: AnalysisType, error: String)

        // Reports
        case reportViewed(reportId: String, reportType: String)
        case reportGenerated(format: String, duration: TimeInterval)
        case reportShared(channel: String)

        // Shop
        case shopViewed
        case tyreProductViewed(brand: String, model: String)
        case shopFiltered(filters: [String: String])

        // Subscription
        case paywallPresented(trigger: PaywallTrigger, plan: String)
        case paywallViewed(trigger: PaywallTrigger, plans: [String])
        case paywallDismissed(trigger: PaywallTrigger, viewDuration: TimeInterval, interacted: Bool)
        case subscriptionPurchased(plan: String, price: Double, daysSinceSignup: Int, trigger: PaywallTrigger)
        case subscriptionCancelled(plan: String, lifetimeDays: Int, reason: String?)

        // Features
        case featureUsed(feature: String, isFirstUse: Bool, userSegment: String)

        // Screens
        case screenLoaded(name: String, duration: TimeInterval, itemCount: Int?)
        case screenViewed(name: String)

        // Performance
        case fpsRecorded(screen: String, fps: Double)
        case apiLatency(endpoint: String, latency: Double, statusCode: Int)
        case apiRequestCompleted(endpoint: String, duration: TimeInterval, success: Bool, statusCode: Int?, errorType: String?)

        // Errors
        case errorOccurred(error: String, screen: String, context: [String: String])
        case errorRecovery(errorId: String, success: Bool, recoveryTime: TimeInterval)

        // Tasks
        case taskStarted(task: String, screen: String)
        case taskCompleted(task: String, duration: TimeInterval, success: Bool, attempts: Int)

        // User Feedback
        case npsSurveyCompleted(score: Int, category: NPSCategory, feedback: String?, userSegment: String)
        case featureSatisfaction(feature: String, rating: Int, context: String)

        // Referrals
        case inviteSent(userId: String, channel: String)
        case referralSignup(referrerId: String, refereeId: String)

        // Accessibility
        case accessibilityFeatureUsed(feature: String, enabled: Bool)
        case dynamicTypeUsed(category: String)

        var name: String {
            switch self {
            case .appOpened: return "app_opened"
            case .appLaunched: return "app_launched"
            case .sessionStarted: return "session_started"
            case .sessionEnded: return "session_ended"
            case .userSignedUp: return "user_signed_up"
            case .userLoggedIn: return "user_logged_in"
            case .userLoggedOut: return "user_logged_out"
            case .onboardingStepViewed: return "onboarding_step_viewed"
            case .onboardingCompleted: return "onboarding_completed"
            case .onboardingSkipped: return "onboarding_skipped"
            case .vehicleAddMethodSelected: return "vehicle_add_method_selected"
            case .plateDetected: return "plate_detected"
            case .plateScanFailed: return "plate_scan_failed"
            case .vehicleAdded: return "vehicle_added"
            case .firstVehicleAdded: return "first_vehicle_added"
            case .vehicleViewed: return "vehicle_viewed"
            case .vehicleDeleted: return "vehicle_deleted"
            case .tyreRegistered: return "tyre_registered"
            case .tyreAnalysisStarted: return "tyre_analysis_started"
            case .tyreAnalysisCompleted: return "tyre_analysis_completed"
            case .tyreAnalysisFailed: return "tyre_analysis_failed"
            case .reportViewed: return "report_viewed"
            case .reportGenerated: return "report_generated"
            case .reportShared: return "report_shared"
            case .shopViewed: return "shop_viewed"
            case .tyreProductViewed: return "tyre_product_viewed"
            case .shopFiltered: return "shop_filtered"
            case .paywallPresented: return "paywall_presented"
            case .paywallViewed: return "paywall_viewed"
            case .paywallDismissed: return "paywall_dismissed"
            case .subscriptionPurchased: return "subscription_purchased"
            case .subscriptionCancelled: return "subscription_cancelled"
            case .featureUsed: return "feature_used"
            case .screenLoaded: return "screen_loaded"
            case .screenViewed: return "screen_viewed"
            case .fpsRecorded: return "fps_recorded"
            case .apiLatency: return "api_latency"
            case .apiRequestCompleted: return "api_request_completed"
            case .errorOccurred: return "error_occurred"
            case .errorRecovery: return "error_recovery"
            case .taskStarted: return "task_started"
            case .taskCompleted: return "task_completed"
            case .npsSurveyCompleted: return "nps_survey_completed"
            case .featureSatisfaction: return "feature_satisfaction"
            case .inviteSent: return "invite_sent"
            case .referralSignup: return "referral_signup"
            case .accessibilityFeatureUsed: return "accessibility_feature_used"
            case .dynamicTypeUsed: return "dynamic_type_used"
            }
        }

        var parameters: [String: Any] {
            switch self {
            case .appOpened(let timestamp):
                return ["timestamp": timestamp.ISO8601Format()]

            case .appLaunched(let coldStartTime):
                return ["cold_start_time": coldStartTime]

            case .sessionStarted(let sessionId):
                return ["session_id": sessionId]

            case .sessionEnded(let sessionId, let duration, let screensVisited, let actions):
                return [
                    "session_id": sessionId,
                    "duration": duration,
                    "screens_visited": screensVisited,
                    "actions": actions
                ]

            case .userSignedUp(let method, let source):
                return [
                    "method": method.rawValue,
                    "source": source ?? "unknown"
                ]

            case .userLoggedIn(let method):
                return ["method": method.rawValue]

            case .userLoggedOut:
                return [:]

            case .onboardingStepViewed(let step, let timestamp):
                return [
                    "step": step,
                    "timestamp": timestamp.ISO8601Format()
                ]

            case .onboardingCompleted(let duration, let stepsViewed):
                return [
                    "duration": duration,
                    "steps_viewed": stepsViewed
                ]

            case .onboardingSkipped(let lastStep):
                return ["last_step": lastStep]

            case .vehicleAddMethodSelected(let method, let screen):
                return [
                    "method": method.rawValue,
                    "screen": screen
                ]

            case .plateDetected(let duration, let attempts, let confidence):
                return [
                    "duration": duration,
                    "attempts": attempts,
                    "confidence": confidence
                ]

            case .plateScanFailed(let reason, let attempts):
                return [
                    "reason": reason,
                    "attempts": attempts
                ]

            case .vehicleAdded(let method, let timeSinceSignup):
                var params: [String: Any] = ["method": method.rawValue]
                if let time = timeSinceSignup {
                    params["time_since_signup"] = time
                }
                return params

            case .firstVehicleAdded(let timeSinceSignup, let method):
                return [
                    "time_since_signup": timeSinceSignup,
                    "method": method.rawValue
                ]

            case .vehicleViewed(let vehicleId):
                return ["vehicle_id": vehicleId]

            case .vehicleDeleted(let vehicleId, let vehicleAge):
                return [
                    "vehicle_id": vehicleId,
                    "vehicle_age": vehicleAge
                ]

            case .tyreRegistered(let method):
                return ["method": method.rawValue]

            case .tyreAnalysisStarted(let type):
                return ["type": type.rawValue]

            case .tyreAnalysisCompleted(let type, let duration, let success, let imageSize):
                var params: [String: Any] = [
                    "type": type.rawValue,
                    "duration": duration,
                    "success": success
                ]
                if let size = imageSize {
                    params["image_width"] = size.width
                    params["image_height"] = size.height
                }
                return params

            case .tyreAnalysisFailed(let type, let error):
                return [
                    "type": type.rawValue,
                    "error": error
                ]

            case .reportViewed(let reportId, let reportType):
                return [
                    "report_id": reportId,
                    "report_type": reportType
                ]

            case .reportGenerated(let format, let duration):
                return [
                    "format": format,
                    "duration": duration
                ]

            case .reportShared(let channel):
                return ["channel": channel]

            case .shopViewed:
                return [:]

            case .tyreProductViewed(let brand, let model):
                return [
                    "brand": brand,
                    "model": model
                ]

            case .shopFiltered(let filters):
                return ["filters": filters]

            case .paywallPresented(let trigger, let plan):
                return [
                    "trigger": trigger.rawValue,
                    "plan": plan
                ]

            case .paywallViewed(let trigger, let plans):
                return [
                    "trigger": trigger.rawValue,
                    "plans": plans
                ]

            case .paywallDismissed(let trigger, let viewDuration, let interacted):
                return [
                    "trigger": trigger.rawValue,
                    "view_duration": viewDuration,
                    "interacted": interacted
                ]

            case .subscriptionPurchased(let plan, let price, let daysSinceSignup, let trigger):
                return [
                    "plan": plan,
                    "price": price,
                    "days_since_signup": daysSinceSignup,
                    "trigger": trigger.rawValue
                ]

            case .subscriptionCancelled(let plan, let lifetimeDays, let reason):
                var params: [String: Any] = [
                    "plan": plan,
                    "lifetime_days": lifetimeDays
                ]
                if let reason = reason {
                    params["reason"] = reason
                }
                return params

            case .featureUsed(let feature, let isFirstUse, let userSegment):
                return [
                    "feature": feature,
                    "is_first_use": isFirstUse,
                    "user_segment": userSegment
                ]

            case .screenLoaded(let name, let duration, let itemCount):
                var params: [String: Any] = [
                    "name": name,
                    "duration": duration
                ]
                if let count = itemCount {
                    params["item_count"] = count
                }
                return params

            case .screenViewed(let name):
                return ["name": name]

            case .fpsRecorded(let screen, let fps):
                return [
                    "screen": screen,
                    "fps": fps
                ]

            case .apiLatency(let endpoint, let latency, let statusCode):
                return [
                    "endpoint": endpoint,
                    "latency": latency,
                    "status_code": statusCode
                ]

            case .apiRequestCompleted(let endpoint, let duration, let success, let statusCode, let errorType):
                var params: [String: Any] = [
                    "endpoint": endpoint,
                    "duration": duration,
                    "success": success
                ]
                if let code = statusCode {
                    params["status_code"] = code
                }
                if let error = errorType {
                    params["error_type"] = error
                }
                return params

            case .errorOccurred(let error, let screen, let context):
                return [
                    "error": error,
                    "screen": screen,
                    "context": context
                ]

            case .errorRecovery(let errorId, let success, let recoveryTime):
                return [
                    "error_id": errorId,
                    "success": success,
                    "recovery_time": recoveryTime
                ]

            case .taskStarted(let task, let screen):
                return [
                    "task": task,
                    "screen": screen
                ]

            case .taskCompleted(let task, let duration, let success, let attempts):
                return [
                    "task": task,
                    "duration": duration,
                    "success": success,
                    "attempts": attempts
                ]

            case .npsSurveyCompleted(let score, let category, let feedback, let userSegment):
                var params: [String: Any] = [
                    "score": score,
                    "category": category.rawValue,
                    "user_segment": userSegment
                ]
                if let feedback = feedback {
                    params["feedback"] = feedback
                }
                return params

            case .featureSatisfaction(let feature, let rating, let context):
                return [
                    "feature": feature,
                    "rating": rating,
                    "context": context
                ]

            case .inviteSent(let userId, let channel):
                return [
                    "user_id": userId,
                    "channel": channel
                ]

            case .referralSignup(let referrerId, let refereeId):
                return [
                    "referrer_id": referrerId,
                    "referee_id": refereeId
                ]

            case .accessibilityFeatureUsed(let feature, let enabled):
                return [
                    "feature": feature,
                    "enabled": enabled
                ]

            case .dynamicTypeUsed(let category):
                return ["category": category]
            }
        }

        var timestamp: Date {
            return Date()
        }

        var userId: String? {
            return AuthService.shared.currentUserId
        }
    }

    // MARK: - Flush

    private func flush() async {
        guard !eventQueue.isEmpty else { return }

        let eventsToSend = eventQueue
        eventQueue.removeAll()

        do {
            try await sendToBackend(eventsToSend)
        } catch {
            // Re-queue events on failure
            eventQueue.append(contentsOf: eventsToSend)
            logger.error("Failed to send analytics: \(error.localizedDescription)")
        }
    }

    private func sendToBackend(_ events: [Event]) async throws {
        let payload: [[String: Any]] = events.map { event in
            var eventData: [String: Any] = [
                "name": event.name,
                "parameters": event.parameters,
                "timestamp": event.timestamp.ISO8601Format()
            ]
            if let userId = event.userId {
                eventData["user_id"] = userId
            }
            return eventData
        }

        let body: [String: Any] = ["events": payload]

        // Try to send to backend, but don't fail if endpoint doesn't exist yet
        do {
            let _: EmptyResponse? = try await networkManager.request(
                endpoint: "/analytics/events",
                method: .post,
                body: body
            )
        } catch {
            // Silently fail for now since endpoint might not exist
            logger.debug("Analytics endpoint not available: \(error.localizedDescription)")
        }
    }

    private func startPeriodicFlush() {
        Task {
            while true {
                try? await Task.sleep(nanoseconds: UInt64(flushInterval * 1_000_000_000))
                await flush()
            }
        }
    }

    // MARK: - User Properties

    func setUserProperty(key: String, value: String) {
        // Store user properties for enrichment
        UserDefaults.standard.set(value, forKey: "analytics_user_\(key)")
    }

    func getUserProperty(key: String) -> String? {
        return UserDefaults.standard.string(forKey: "analytics_user_\(key)")
    }
}

// MARK: - Empty Response

private struct EmptyResponse: Codable {}
