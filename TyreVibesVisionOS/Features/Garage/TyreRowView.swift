#if os(visionOS)
import SwiftUI

struct TyreRowView: View {
    let tyre: VisionTyreSnapshot

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.18), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(tyre.position)
                    .font(.headline)

                Text(tyre.model)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }

    private var tint: Color {
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

    private var iconName: String {
        switch tyre.healthState {
        case .unknown:
            return "questionmark.circle.fill"
        case .optimal:
            return "checkmark.circle.fill"
        case .monitor:
            return "exclamationmark.triangle.fill"
        case .critical:
            return "xmark.octagon.fill"
        }
    }
}
#endif
