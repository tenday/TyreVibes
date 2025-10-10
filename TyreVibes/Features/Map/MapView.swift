import SwiftUI
import MapKit

struct MapView: View {
    @StateObject private var mapManager = MapManager()
    @State private var cameraPosition: MapCameraPosition
    @State private var searchText = ""
    @State private var selectedCategory: MapSearchCategory = .all
    @State private var selectedResult: MKMapItem?
    @Namespace private var categoryAnimation
    @FocusState private var isSearchFieldFocused: Bool

    init() {
        let center = CLLocationCoordinate2D(latitude: 41.9028, longitude: 12.4964) // Rome
        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(center: center, latitudinalMeters: 250_000, longitudinalMeters: 250_000)))
    }

    var body: some View {
        ZStack(alignment: .top) {
            mapLayer
                .ignoresSafeArea()

            topGlow

            VStack(spacing: 12) {
                searchBar
                categoryStrip
            }
            .padding(.horizontal)
            .padding(.top, 52)
        }
        .overlay(alignment: .bottom) {
            bottomPanel
        }
        .onAppear {
            if mapManager.searchResults.isEmpty {
                performSearch()
            }
        }
        .onChange(of: mapManager.searchResults) { newValue in
            guard !newValue.isEmpty else {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    selectedResult = nil
                }
                return
            }

            let coordinates = newValue.map { $0.placemark.coordinate }
            let region = regionFor(coordinates: coordinates)

            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                cameraPosition = .region(region)
            }

            if let current = selectedResult, newValue.contains(current) {
                selectedResult = current
            } else {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    selectedResult = newValue.first
                }
            }
        }
        .onChange(of: selectedCategory) { _ in
            performSearch(haptics: true)
        }
    }

    private var mapLayer: some View {
        Map(position: $cameraPosition) {
            ForEach(mapManager.searchResults, id: \.self) { item in
                Annotation(item.name ?? "Officina", coordinate: item.placemark.coordinate) {
                    CustomMarkerView(isSelected: selectedResult == item)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                selectedResult = item
                                focusOn(item)
                            }
                        }
                }
            }
        }
        .mapControls {
            MapCompass()
            MapPitchToggle()
        }
        .overlay(alignment: .bottomTrailing) {
            zoomControls
        }
        .overlay(alignment: .bottomLeading) {
            if #available(iOS 17.0, *) {
                MapUserLocationButton()
                    .buttonBorderShape(.capsule)
                    .tint(.white.opacity(0.85))
                    .labelStyle(.iconOnly)
                    .symbolRenderingMode(.multicolor)
                    .padding(.leading, 16)
                    .padding(.bottom, 120)
            }
        }
    }

    private var topGlow: some View {
        LinearGradient(
            colors: [
                Color.customPurple.opacity(0.35),
                Color.customAzure.opacity(0.12),
                .clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(height: 240)
        .blur(radius: 40)
        .allowsHitTesting(false)
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles.magnifyingglass")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.customAzure, .customBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(isSearchFieldFocused ? 1.1 : 1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSearchFieldFocused)

            TextField("Cerca officine, gommisti o servizi premium...", text: $searchText)
                .focused($isSearchFieldFocused)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .foregroundColor(.white)
                .submitLabel(.search)
                .onSubmit { performSearch(haptics: true) }

            if !searchText.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        searchText = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.65))
                        .accessibilityLabel("Cancella ricerca")
                }
            }

            Button {
                performSearch(haptics: true)
            } label: {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.customBlue, .customAzure],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .customBlue.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .accessibilityLabel("Avvia ricerca")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 18)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.25),
                            .white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(MapSearchCategory.allCases) { category in
                    categoryChip(for: category)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
    }

    private func categoryChip(for category: MapSearchCategory) -> some View {
        let isSelected = selectedCategory == category

        return Button {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                selectedCategory = category
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: category.iconName)
                    .font(.system(size: 14, weight: .semibold))
                Text(category.title)
                    .font(.customFont(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .foregroundColor(.white)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: category.gradientColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .matchedGeometryEffect(id: "chip_background", in: categoryAnimation)
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.customFieldColor)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(isSelected ? 0.35 : 0.12), lineWidth: 1)
            )
            .shadow(color: isSelected ? category.shadowColor : .clear, radius: 18, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }

    private var zoomControls: some View {
        VStack(spacing: 12) {
            Button(action: zoomIn) {
                controlIcon("plus")
            }

            Button(action: zoomOut) {
                controlIcon("minus")
            }
        }
        .padding()
    }

    private func controlIcon(_ symbol: String) -> some View {
        Image(systemName: "\(symbol).magnifyingglass")
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.white)
            .padding(14)
            .background(
                Circle()
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 6)
            )
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.25), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }

    private var bottomPanel: some View {
        VStack(spacing: 16) {
            if mapManager.isSearching {
                ProgressView("Stiamo cercando le officine migliori…")
                    .font(.customFont(size: 14, weight: .medium))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        Capsule(style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .tint(.customAzure)
            }

            if !mapManager.searchResults.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(mapManager.searchResults, id: \.self) { item in
                            resultCard(for: item)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                }
            } else if !mapManager.isSearching {
                VStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.customAzure)

                    Text("Nessun risultato trovato.")
                        .font(.customFont(size: 15, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Prova a spostare la mappa o cambia categoria.")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 28)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.45),
                    Color.black.opacity(0.25),
                    .clear
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private func resultCard(for item: MKMapItem) -> some View {
        let isSelected = selectedResult == item

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.customFieldColor)
                        .frame(width: 42, height: 42)
                    Image(systemName: isSelected ? "sparkles" : "map.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isSelected ? .customAzure : .white.opacity(0.8))
                        .shadow(color: .customAzure.opacity(isSelected ? 0.6 : 0), radius: 12, x: 0, y: 0)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name ?? "Officina senza nome")
                        .font(.customFont(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)

                    if let subtitle = item.placemark.title {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(2)
                    }

                    if let distanceText = distanceText(for: item) {
                        Label(distanceText, systemImage: "location.circle")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.customAzure)
                    }
                }
            }

            if isSelected {
                Button {
                    openInMaps(item)
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                        Text("Apri in Mappe")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.customBlue)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(
                        Capsule(style: .continuous)
                            .fill(.white.opacity(0.18))
                    )
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(18)
        .frame(width: 260, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: isSelected
                            ? [.customAzure, .customBlue.opacity(0.8)]
                            : [.white.opacity(0.2), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                selectedResult = item
                focusOn(item, animated: true)
            }
        }
    }

    private func performSearch(haptics: Bool = false) {
        guard let region = cameraPosition.region else { return }

        let trimmedText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseQuery = trimmedText.isEmpty ? selectedCategory.defaultQuery : trimmedText

        mapManager.searchPlaces(
            query: baseQuery,
            categoryHint: selectedCategory.categoryHint,
            region: region
        )

        if haptics {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        isSearchFieldFocused = false
    }

    private func focusOn(_ item: MKMapItem, animated: Bool = false) {
        let coordinate = item.placemark.coordinate
        let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 12_000, longitudinalMeters: 12_000)

        if animated {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                cameraPosition = .region(region)
            }
        } else {
            cameraPosition = .region(region)
        }
    }

    private func distanceText(for item: MKMapItem) -> String? {
        guard let region = cameraPosition.region else { return nil }
        let centerLocation = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
        let itemLocation = CLLocation(latitude: item.placemark.coordinate.latitude, longitude: item.placemark.coordinate.longitude)

        let distance = centerLocation.distance(from: itemLocation)
        guard distance > 0 else { return nil }

        if distance < 1_000 {
            return "\(Int(distance)) m"
        } else {
            let measurement = Measurement(value: distance / 1_000, unit: UnitLength.kilometers)
            let formatter = MeasurementFormatter()
            formatter.unitOptions = .providedUnit
            formatter.numberFormatter.maximumFractionDigits = 1
            return formatter.string(from: measurement)
        }
    }

    /// Calculates a region that encompasses a list of coordinates with padding.
    private func regionFor(coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion()
        }

        if coordinates.count == 1, let coordinate = coordinates.first {
            return MKCoordinateRegion(center: coordinate, latitudinalMeters: 12_000, longitudinalMeters: 12_000)
        }

        var minLat: CLLocationDegrees = 90.0
        var maxLat: CLLocationDegrees = -90.0
        var minLon: CLLocationDegrees = 180.0
        var maxLon: CLLocationDegrees = -180.0

        coordinates.forEach { coordinate in
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(latitudeDelta: (maxLat - minLat) * 1.5, longitudeDelta: (maxLon - minLon) * 1.5)

        return MKCoordinateRegion(center: center, span: span)
    }

    private func zoomIn() {
        zoom(by: 0.6)
    }

    private func zoomOut() {
        zoom(by: 1.4)
    }

    private func zoom(by factor: Double) {
        guard let region = cameraPosition.region else { return }

        let latitudeDelta = max(region.span.latitudeDelta * factor, 0.0005)
        let longitudeDelta = max(region.span.longitudeDelta * factor, 0.0005)

        let newRegion = MKCoordinateRegion(
            center: region.center,
            span: MKCoordinateSpan(
                latitudeDelta: min(latitudeDelta, 100),
                longitudeDelta: min(longitudeDelta, 100)
            )
        )

        withAnimation(.easeInOut(duration: 0.25)) {
            cameraPosition = .region(newRegion)
        }
    }

    /// Opens the given map item in the Apple Maps app with driving directions as default.
    private func openInMaps(_ item: MKMapItem) {
        // Prefer using the item's own name; fall back to a generic label
        item.name = item.name ?? "Destinazione"

        // Configure launch options (driving by default)
        let launchOptions = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ]

        // Open the item in Maps
        item.openInMaps(launchOptions: launchOptions)
    }
}

private enum MapSearchCategory: CaseIterable, Identifiable {
    case all
    case tyres
    case emergency
    case premium

    var id: Self { self }

    var title: String {
        switch self {
        case .all:
            return "Vicino a te"
        case .tyres:
            return "Cambio gomme"
        case .emergency:
            return "Soccorso 24H"
        case .premium:
            return "Premium"
        }
    }

    var iconName: String {
        switch self {
        case .all:
            return "sparkles"
        case .tyres:
            return "wrench.and.screwdriver.fill"
        case .emergency:
            return "bolt.fill"
        case .premium:
            return "star.fill"
        }
    }

    var defaultQuery: String {
        switch self {
        case .all:
            return "gommista"
        case .tyres:
            return "cambio gomme"
        case .emergency:
            return "soccorso stradale"
        case .premium:
            return "officina premium"
        }
    }

    var categoryHint: String? {
        switch self {
        case .all:
            return nil
        case .tyres:
            return "montaggio pneumatici"
        case .emergency:
            return "aperto 24 ore"
        case .premium:
            return "recensioni alte lusso"
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .all:
            return [.customBlue, .customAzure]
        case .tyres:
            return [.customBlue, .customPurple]
        case .emergency:
            return [.customBitterSweet, .customSandyBrown]
        case .premium:
            return [.customPurple, .customAzure]
        }
    }

    var shadowColor: Color {
        switch self {
        case .all:
            return .customBlue.opacity(0.35)
        case .tyres:
            return .customBlue.opacity(0.35)
        case .emergency:
            return .customBitterSweet.opacity(0.35)
        case .premium:
            return .customPurple.opacity(0.35)
        }
    }
}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView()
            .preferredColorScheme(.dark)
    }
}
