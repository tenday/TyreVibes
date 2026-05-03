#if os(visionOS)
import Foundation

struct VisionTyreSnapshot: Identifiable, Hashable {
    enum HealthState: String {
        case optimal
        case monitor
        case critical

        var title: String {
            switch self {
            case .optimal:
                return "Ottimo"
            case .monitor:
                return "Da monitorare"
            case .critical:
                return "Critico"
            }
        }
    }

    let id = UUID()
    let position: String
    let model: String
    let treadDepthMillimeters: Double
    let pressureBar: Double
    let healthState: HealthState
}
#endif
