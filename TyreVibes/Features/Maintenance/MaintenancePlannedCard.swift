import SwiftUI

struct MaintenancePlannedCard: View {
    let item: MaintenanceSchedule
    var isNext: Bool = false
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(item.type.color.opacity(0.20))
                        .frame(width: 38, height: 38)
                    MaintenanceTypeIconView(type: item.type, color: item.type.color, size: 15)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(item.title)
                            .font(.customFont(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        if isNext {
                            Text("NEXT")
                                .font(.customFont(size: 8, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 3)
                                .background(Color.white, in: Capsule())
                        }
                    }

                    Text(item.formattedDate)
                        .font(.customFont(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(item.relativeTimeString)
                        .font(.customFont(size: 11, weight: .semibold))
                        .foregroundColor(item.isOverdue ? .orange : .cyan)
                        .lineLimit(1)

                    Text(item.priority.label)
                        .font(.customFont(size: 9, weight: .medium))
                        .foregroundColor(item.priority.color)
                        .lineLimit(1)
                }
            }

            Text(item.description)
                .font(.customFont(size: 12, weight: .regular))
                .foregroundColor(.white.opacity(0.72))

            HStack(spacing: 8) {
                if let costText {
                    Label(costText, systemImage: "eurosign.circle")
                        .font(.customFont(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.72))
                }
                Spacer()

                Button {
                    onComplete()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                        Text("Fatto")
                            .font(.customFont(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Color.green.opacity(0.95), in: Capsule())
                }

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.1), in: Circle())
                }
            }
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isNext ? 0.10 : 0.065),
                            item.type.color.opacity(isNext ? 0.10 : 0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isNext ? item.type.color.opacity(0.34) : Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}
