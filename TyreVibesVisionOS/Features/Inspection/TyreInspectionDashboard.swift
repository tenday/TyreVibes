#if os(visionOS)
import Foundation
import SwiftUI

struct TyreInspectionDashboard: View {
    let tyre: VisionTyreSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            header

            HStack(spacing: 16) {
                VisionMetricBadge(
                    title: "Battistrada",
                    value: tyre.treadDepthMillimeters > 0 ? String(format: "%.1f mm", tyre.treadDepthMillimeters) : "n/d",
                    systemImage: "ruler",
                    tint: treadTint
                )

                VisionMetricBadge(
                    title: "Pressione",
                    value: tyre.pressureBar > 0 ? String(format: "%.1f bar", tyre.pressureBar) : "n/d",
                    systemImage: "gauge.with.dots.needle.67percent",
                    tint: .blue
                )

                VisionMetricBadge(
                    title: "Stato",
                    value: tyre.healthState.title,
                    systemImage: "heart.text.square",
                    tint: stateTint
                )
            }

            TyreScanPlaceholderView(tyre: tyre)

            Spacer()
        }
        .padding(32)
        .navigationTitle("Ispezione")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tyre.position)
                .font(.largeTitle.weight(.bold))

            Text(tyre.model)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var treadTint: Color {
        guard tyre.treadDepthMillimeters > 0 else { return .gray }
        return tyre.treadDepthMillimeters <= 3.0 ? Color.red : Color.green
    }

    private var stateTint: Color {
        switch tyre.healthState {
        case .unknown:
            return .gray
        case .optimal:
            return .green
        case .monitor:
            return .orange
        case .critical:
            return .red
        }
    }
}

#Preview(windowStyle: .automatic) {
    TyreInspectionDashboard(
        tyre: VisionTyreSnapshot(
            position: "Anteriore sinistra",
            model: "Michelin Pilot Sport 4",
            treadDepthMillimeters: 6.4,
            pressureBar: 2.4,
            healthState: .optimal
        )
    )
}
#endif
