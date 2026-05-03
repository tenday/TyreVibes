#if os(visionOS)
import Combine
import Foundation

@MainActor
final class VisionGarageStore: ObservableObject {
    @Published var selectedTyreID: VisionTyreSnapshot.ID?

    let tyres: [VisionTyreSnapshot] = [
        VisionTyreSnapshot(
            position: "Anteriore sinistra",
            model: "Michelin Pilot Sport 4",
            treadDepthMillimeters: 6.4,
            pressureBar: 2.4,
            healthState: .optimal
        ),
        VisionTyreSnapshot(
            position: "Anteriore destra",
            model: "Michelin Pilot Sport 4",
            treadDepthMillimeters: 6.1,
            pressureBar: 2.3,
            healthState: .optimal
        ),
        VisionTyreSnapshot(
            position: "Posteriore sinistra",
            model: "Pirelli Cinturato P7",
            treadDepthMillimeters: 3.5,
            pressureBar: 2.1,
            healthState: .monitor
        ),
        VisionTyreSnapshot(
            position: "Posteriore destra",
            model: "Pirelli Cinturato P7",
            treadDepthMillimeters: 2.7,
            pressureBar: 2.0,
            healthState: .critical
        )
    ]

    var selectedTyre: VisionTyreSnapshot {
        tyres.first { $0.id == selectedTyreID } ?? tyres[0]
    }

    func select(_ tyre: VisionTyreSnapshot) {
        selectedTyreID = tyre.id
    }
}
#endif
