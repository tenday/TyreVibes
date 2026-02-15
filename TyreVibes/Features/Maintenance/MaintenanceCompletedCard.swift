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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: displayIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(displayColor)
                    .frame(width: 30, height: 30)
                    .background(displayColor.opacity(0.18), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                        .font(.customFont(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text("\(entry.source.label) • \(formatter.string(from: entry.date))")
                        .font(.customFont(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
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
            }

            HStack(spacing: 12) {
                if let mileage = entry.mileage {
                    Label("Km: \(mileage)", systemImage: "speedometer")
                        .font(.customFont(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.72))
                }

                if let workshopName = entry.workshopName, !workshopName.isEmpty {
                    Label(workshopName, systemImage: "building.2")
                        .font(.customFont(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.72))
                        .lineLimit(1)
                }

                if let type = entry.maintenanceType {
                    Text(type.category.localizedName)
                        .font(.customFont(size: 10, weight: .medium))
                        .foregroundColor(type.color.opacity(0.9))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(type.color.opacity(0.15), in: Capsule())
                }

                if let ids = entry.attachmentIds, !ids.isEmpty {
                    Label("\(ids.count)", systemImage: "paperclip")
                        .font(.customFont(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}
