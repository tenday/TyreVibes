#if os(visionOS)
import SwiftUI

struct TyreScanPlaceholderView: View {
    let tyre: VisionTyreSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("Anteprima scansione", systemImage: "viewfinder")
                    .font(.headline)

                Spacer()

                Text(tyre.healthState.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.thinMaterial)

                VStack(spacing: 18) {
                    Image(systemName: "tirepressure")
                        .font(.system(size: 76, weight: .light))
                        .foregroundStyle(.secondary)

                    Text("Area pronta per LiDAR, RealityKit o modello 3D del pneumatico")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 280)
        }
        .padding(22)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
#endif
