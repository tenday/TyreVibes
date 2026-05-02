import SwiftUI

struct MaintenanceCompletedCard: View {
    let entry: CompletedMaintenanceEntry

    private var formatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }

    private var displayIcon: String {
        if let type = entry.maintenanceType {
            return type.icon
        }
        switch entry.source {
        case .manual: return "square.and.pencil"
        case .partner: return "building.2.fill"
        case .automatic: return "gearshape.2.fill"
        }
    }

    private var displayColor: Color {
        if let type = entry.maintenanceType {
            return type.color
        }
        switch entry.source {
        case .manual: return .orange
        case .partner: return .green
        case .automatic: return .blue
        }
    }

    private var costText: String? {
        guard let cost = entry.cost else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: cost))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Group {
                    if let type = entry.maintenanceType {
                        MaintenanceTypeIconView(type: type, color: displayColor, size: 13)
                    } else {
                        Image(systemName: displayIcon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(displayColor)
                    }
                }
                    .frame(width: 30, height: 30)
                    .background(displayColor.opacity(0.18), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                        .font(.customFont(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text("\(entry.source.label) • \(formatter.string(from: entry.date))")
                        .font(.customFont(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
                Spacer()

                if let costText {
                    Text(costText)
                        .font(.customFont(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                }
            }

            if let note = entry.note, !note.isEmpty {
                Text(note)
                    .font(.customFont(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.78))
                    .lineLimit(2)
            }

            FlowingMaintenanceMetaRow(
                entry: entry,
                displayColor: displayColor
            )
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct FlowingMaintenanceMetaRow: View {
    let entry: CompletedMaintenanceEntry
    let displayColor: Color

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let mileage = entry.mileage {
                    metaPill("Km \(mileage)", icon: "speedometer", color: .cyan)
                }

                if let workshopName = entry.workshopName, !workshopName.isEmpty {
                    metaPill(workshopName, icon: "building.2", color: .white.opacity(0.72))
                }

                if let type = entry.maintenanceType {
                    metaPill(type.category.localizedName, icon: type.category.icon, color: type.color)
                }

                if let ids = entry.attachmentIds, !ids.isEmpty {
                    metaPill("\(ids.count)", icon: "paperclip", color: displayColor)
                }
            }
        }
    }

    private func metaPill(_ text: String, icon: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.customFont(size: 11, weight: .medium))
            .foregroundColor(color)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
    }
}
