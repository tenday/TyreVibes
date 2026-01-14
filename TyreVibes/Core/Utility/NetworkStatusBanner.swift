import SwiftUI

struct NetworkStatusBanner: View {
    let isVisible: Bool

    var body: some View {
        if isVisible {
            HStack(spacing: 10) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.offlineTitle.localized)
                        .font(.customFont(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text(L10n.offlineMessage.localized)
                        .font(.customFont(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }

                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(Color.red.opacity(0.9))
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 4)
        }
    }
}
