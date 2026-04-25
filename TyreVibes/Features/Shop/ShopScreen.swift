import SwiftUI

struct ShopScreen: View {
    @State private var showNotificationScreen = false

    var body: some View {
        ZStack(alignment: .top) {
            MapView(topInset: 94)

            MarketplaceTopBar(showNotificationScreen: $showNotificationScreen)
                .padding(.horizontal, 18)
                .padding(.top, 12)
        }
        .background(Color.customBackgroundColor.ignoresSafeArea())
        .fullScreenCover(isPresented: $showNotificationScreen) {
            NotificationScreen()
        }
    }
}

private struct MarketplaceTopBar: View {
    @Binding var showNotificationScreen: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Marketplace")
                    .font(.customFont(size: 24, weight: .semibold))
                    .foregroundColor(.white)

                Text("Mappa intelligente per officine e servizi vicini")
                    .font(.customFont(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.62))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            Button {
                showNotificationScreen = true
            } label: {
                Image(systemName: "bell")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Notifiche")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }
}

#Preview {
    ShopScreen()
}
