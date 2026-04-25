import SwiftUI

struct MaintenancePlannedCard: View {
    let item: MaintenanceSchedule
    let onComplete: () -> Void
    let onDelete: () -> Void

    private var costText: String? {
        guard let cost = item.estimatedCost else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: cost))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(item.type.color.opacity(0.18))
                        .frame(width: 34, height: 34)
                    MaintenanceTypeIconView(type: item.type, color: item.type.color, size: 14)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.customFont(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(item.formattedDate)
                        .font(.customFont(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                Text(item.relativeTimeString)
                    .font(.customFont(size: 11, weight: .medium))
                    .foregroundColor(item.isOverdue ? .orange : .cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background((item.isOverdue ? Color.orange : Color.cyan).opacity(0.15), in: Capsule())
            }

            Text(item.description)
                .font(.customFont(size: 12, weight: .regular))
                .foregroundColor(.white.opacity(0.72))

            HStack {
                if let costText {
                    Text(costText)
                        .font(.customFont(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                }
                Spacer()
                Button("Completa") {
                    onComplete()
                }
                .font(.customFont(size: 12, weight: .semibold))
                .foregroundColor(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.95), in: Capsule())

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(7)
                        .background(Color.white.opacity(0.1), in: Circle())
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
