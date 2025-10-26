import SwiftUI
import MapKit

struct ShopDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let shopInfo: EnhancedShopInfo
    let userLocation: CLLocation?
    let onNavigate: () -> Void
    let onToggleFavorite: () -> Void
    let isFavorite: Bool

    @State private var selectedTab: DetailTab = .info

    enum DetailTab: String, CaseIterable {
        case info = "Info"
        case contact = "Contatti"
        case reviews = "Recensioni"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    tabSelector
                    contentSection
                }
                .padding()
            }
            .background(Color.customBackgroundColor)
            .navigationTitle(shopInfo.mapItem.name ?? "Officina")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Shop Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.customBlue, .customPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image("garageMenu")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
            }
            .shadow(color: .customBlue.opacity(0.4), radius: 20, x: 0, y: 10)

            // Name & Status
            VStack(spacing: 8) {
                Text(shopInfo.mapItem.name ?? "Officina")
                    .font(.customFont(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                if let isOpen = shopInfo.isOpenNow {
                    statusBadge(isOpen: isOpen)
                }
            }

            // Rating & Distance
            HStack(spacing: 20) {
                if let rating = shopInfo.rating {
                    ratingView(rating: rating, count: shopInfo.reviewCount ?? 0)
                }

                if let distance = distanceText {
                    distanceView(distance: distance)
                }
            }

            // Action Buttons
            HStack(spacing: 12) {
                navigationButton
                favoriteButton
                shareButton
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.customFieldColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func statusBadge(isOpen: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isOpen ? Color.green : Color.red)
                .frame(width: 8, height: 8)

            Text(isOpen ? "Aperto" : "Chiuso")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isOpen ? .green : .red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill((isOpen ? Color.green : Color.red).opacity(0.15))
        )
    }

    private func ratingView(rating: Double, count: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .font(.system(size: 16))
                .foregroundColor(.customSandyBrown)

            Text(String(format: "%.1f", rating))
                .font(.customFont(size: 16, weight: .bold))
                .foregroundColor(.white)

            Text("(\(count))")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    private func distanceView(distance: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "location.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.customAzure)

            Text(distance)
                .font(.customFont(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private var navigationButton: some View {
        Button(action: onNavigate) {
            Label("Naviga", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                .font(.customFont(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.customBlue, .customAzure],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: .customBlue.opacity(0.4), radius: 12, x: 0, y: 6)
        }
    }

    private var favoriteButton: some View {
        Button(action: onToggleFavorite) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 20))
                .foregroundColor(isFavorite ? .red : .white)
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(Color.customFieldColor)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
    }

    private var shareButton: some View {
        Button {
            shareLocation()
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(Color.customFieldColor)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
    }

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(DetailTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.customFieldColor)
        )
    }

    private func tabButton(_ tab: DetailTab) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedTab = tab
            }
        } label: {
            Text(tab.rawValue)
                .font(.customFont(size: 14, weight: .semibold))
                .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            selectedTab == tab
                                ? LinearGradient(
                                    colors: [.customAzure, .customBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var contentSection: some View {
        switch selectedTab {
        case .info:
            infoContent
        case .contact:
            contactContent
        case .reviews:
            reviewsContent
        }
    }

    private var infoContent: some View {
        VStack(spacing: 16) {
            // Address
            infoRow(
                icon: "mappin.circle.fill",
                title: "Indirizzo",
                content: addressText,
                color: .customBlue
            )

            // Opening Hours
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text("Orari di Apertura")
                        .font(.customFont(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                } icon: {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.customPurple)
                }

                ForEach(shopInfo.openingHours ?? defaultOpeningHours, id: \.self) { hour in
                    Text(hour)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.customFieldColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )

            // Price Level
            if let priceLevel = shopInfo.priceLevel {
                infoRow(
                    icon: "eurosign.circle.fill",
                    title: "Fascia di Prezzo",
                    content: String(repeating: "€", count: priceLevel),
                    color: .customAzure
                )
            }
        }
    }

    private var contactContent: some View {
        VStack(spacing: 16) {
            if let phone = shopInfo.phoneNumber {
                Button {
                    if let url = URL(string: "tel://\(phone.filter { $0.isNumber })") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    infoRow(
                        icon: "phone.circle.fill",
                        title: "Telefono",
                        content: phone,
                        color: .green,
                        showChevron: true
                    )
                }
                .buttonStyle(.plain)
            } else {
                infoRow(
                    icon: "phone.circle.fill",
                    title: "Telefono",
                    content: "Non disponibile",
                    color: .gray
                )
            }

            if let website = shopInfo.website {
                Button {
                    if let url = URL(string: website) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    infoRow(
                        icon: "globe.circle.fill",
                        title: "Sito Web",
                        content: "Visita il sito",
                        color: .customBlue,
                        showChevron: true
                    )
                }
                .buttonStyle(.plain)
            } else {
                infoRow(
                    icon: "globe.circle.fill",
                    title: "Sito Web",
                    content: "Non disponibile",
                    color: .gray
                )
            }

            infoRow(
                icon: "envelope.circle.fill",
                title: "Email",
                content: "info@officina.it",
                color: .customPurple
            )
        }
    }

    private var reviewsContent: some View {
        VStack(spacing: 16) {
            if let rating = shopInfo.rating, let count = shopInfo.reviewCount {
                // Rating Summary
                VStack(spacing: 12) {
                    Text(String(format: "%.1f", rating))
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)

                    HStack(spacing: 4) {
                        ForEach(0..<5) { index in
                            Image(systemName: Double(index) < rating ? "star.fill" : "star")
                                .font(.system(size: 20))
                                .foregroundColor(.customSandyBrown)
                        }
                    }

                    Text("\(count) recensioni")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.customFieldColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )

                // Sample Reviews
                ForEach(0..<3) { index in
                    reviewCard(index: index)
                }
            }
        }
    }

    private func reviewCard(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.customAzure, .customPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(["M", "L", "A"][index])
                            .font(.customFont(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(["Marco Rossi", "Laura Bianchi", "Andrea Verdi"][index])
                        .font(.customFont(size: 15, weight: .semibold))
                        .foregroundColor(.white)

                    HStack(spacing: 4) {
                        ForEach(0..<5) { starIndex in
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.customSandyBrown)
                        }
                    }
                }

                Spacer()

                Text("2 ore fa")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }

            Text("Servizio eccellente! Personale molto competente e prezzi onesti. Consiglio vivamente!")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(3)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.customFieldColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func infoRow(icon: String, title: String, content: String, color: Color, showChevron: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))

                Text(content)
                    .font(.customFont(size: 15, weight: .medium))
                    .foregroundColor(.white)
            }

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.customFieldColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var addressText: String {
        var components: [String] = []

        if let street = shopInfo.mapItem.placemark.thoroughfare {
            components.append(street)
        }

        if let city = shopInfo.mapItem.placemark.locality {
            components.append(city)
        }

        if let postal = shopInfo.mapItem.placemark.postalCode {
            components.append(postal)
        }

        return components.isEmpty ? "Indirizzo non disponibile" : components.joined(separator: ", ")
    }

    private var distanceText: String? {
        guard let userLocation = userLocation else { return nil }

        let shopLocation = CLLocation(
            latitude: shopInfo.mapItem.placemark.coordinate.latitude,
            longitude: shopInfo.mapItem.placemark.coordinate.longitude
        )

        let distance = userLocation.distance(from: shopLocation)

        if distance < 1_000 {
            return String(format: "%.0f m", distance)
        } else {
            let km = distance / 1_000
            return String(format: "%.1f km", km)
        }
    }

    private var defaultOpeningHours: [String] {
        [
            "Lun - Ven: 08:00 - 19:00",
            "Sabato: 08:00 - 13:00",
            "Domenica: Chiuso"
        ]
    }

    private func shareLocation() {
        guard let name = shopInfo.mapItem.name else { return }

        let text = "Guarda questa officina: \(name)"
        let activityVC = UIActivityViewController(activityItems: [text, shopInfo.mapItem], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

struct ShopDetailSheet_Previews: PreviewProvider {
    static var previews: some View {
        ShopDetailSheet(
            shopInfo: EnhancedShopInfo(mapItem: MKMapItem()),
            userLocation: nil,
            onNavigate: {},
            onToggleFavorite: {},
            isFavorite: false
        )
        .preferredColorScheme(.dark)
    }
}
