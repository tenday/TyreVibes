import Foundation
import MapKit
import Contacts

// MARK: - Shop Filter Model
struct ShopFilter {
    var minRating: Double = 0.0
    var maxDistance: Double = 50_000 // meters (50 km)
    var openNow: Bool = false
    var priceRange: PriceRange = .all
    var sortBy: SortOption = .distance

    enum PriceRange: String, CaseIterable {
        case all = "Tutti"
        case budget = "Economico"
        case moderate = "Medio"
        case premium = "Premium"
    }

    enum SortOption: String, CaseIterable {
        case distance = "Distanza"
        case rating = "Valutazione"
        case name = "Nome"
    }
}

// MARK: - Enhanced Shop Info
struct EnhancedShopInfo {
    let mapItem: MKMapItem
    var rating: Double?
    var reviewCount: Int?
    var priceLevel: Int?
    var isOpenNow: Bool?
    var phoneNumber: String?
    var website: String?
    var openingHours: [String]?

    init(mapItem: MKMapItem) {
        self.mapItem = mapItem

        // Extract additional information if available
        if let phoneNumber = mapItem.phoneNumber {
            self.phoneNumber = phoneNumber
        }

        if let url = mapItem.url {
            self.website = url.absoluteString
        }

        // Simulate rating (in real app, would come from API)
        self.rating = Double.random(in: 3.5...5.0)
        self.reviewCount = Int.random(in: 10...500)
        self.priceLevel = Int.random(in: 1...3)
        self.isOpenNow = Bool.random()
    }
}

class MapManager: NSObject, ObservableObject {

    @Published var searchResults: [MKMapItem] = []
    @Published var enhancedResults: [EnhancedShopInfo] = []
    @Published var filteredResults: [EnhancedShopInfo] = []
    @Published var isSearching: Bool = false
    @Published var currentFilter = ShopFilter()
    @Published var searchHistory: [String] = []
    @Published var favoriteLocations: Set<String> = []

    private var userLocation: CLLocation?
    private let maxHistoryCount = 10

    // MARK: - Search
    func searchPlaces(query: String, categoryHint: String?, region: MKCoordinateRegion, userLocation: CLLocation? = nil) {
        self.userLocation = userLocation

        let searchRequest = MKLocalSearch.Request()
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        var components: [String] = []

        if !trimmedQuery.isEmpty {
            components.append(trimmedQuery)
            addToSearchHistory(trimmedQuery)
        }

        components.append("officina")

        if let hint = categoryHint?.trimmingCharacters(in: .whitespacesAndNewlines), !hint.isEmpty {
            components.append(hint)
        }

        if components.isEmpty {
            components = ["officina", "gommista"]
        }

        searchRequest.naturalLanguageQuery = components.joined(separator: " ")
        searchRequest.region = region
        searchRequest.resultTypes = [.pointOfInterest, .address]

        DispatchQueue.main.async { [weak self] in
            self?.isSearching = true
        }

        let search = MKLocalSearch(request: searchRequest)
        search.start { [weak self] (response, error) in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if let response = response {
                    self.searchResults = response.mapItems
                    self.enhancedResults = response.mapItems.map { EnhancedShopInfo(mapItem: $0) }
                    self.applyFilters()
                } else {
                    if let error = error {
                        print("Error during search: \(error.localizedDescription)")
                    }
                    self.searchResults = []
                    self.enhancedResults = []
                    self.filteredResults = []
                }

                self.isSearching = false
            }
        }
    }

    // MARK: - Filtering
    func applyFilters() {
        var results = enhancedResults

        // Filter by rating
        if currentFilter.minRating > 0 {
            results = results.filter { ($0.rating ?? 0) >= currentFilter.minRating }
        }

        // Filter by distance
        if let userLocation = userLocation {
            results = results.filter { shop in
                let shopLocation = CLLocation(
                    latitude: shop.mapItem.placemark.coordinate.latitude,
                    longitude: shop.mapItem.placemark.coordinate.longitude
                )
                let distance = userLocation.distance(from: shopLocation)
                return distance <= currentFilter.maxDistance
            }
        }

        // Filter by open now
        if currentFilter.openNow {
            results = results.filter { $0.isOpenNow == true }
        }

        // Filter by price range
        switch currentFilter.priceRange {
        case .budget:
            results = results.filter { ($0.priceLevel ?? 2) == 1 }
        case .moderate:
            results = results.filter { ($0.priceLevel ?? 2) == 2 }
        case .premium:
            results = results.filter { ($0.priceLevel ?? 2) == 3 }
        case .all:
            break
        }

        // Sort results
        results = sortResults(results)

        filteredResults = results
        searchResults = results.map { $0.mapItem }
    }

    private func sortResults(_ results: [EnhancedShopInfo]) -> [EnhancedShopInfo] {
        switch currentFilter.sortBy {
        case .distance:
            guard let userLocation = userLocation else { return results }
            return results.sorted { shop1, shop2 in
                let loc1 = CLLocation(latitude: shop1.mapItem.placemark.coordinate.latitude, longitude: shop1.mapItem.placemark.coordinate.longitude)
                let loc2 = CLLocation(latitude: shop2.mapItem.placemark.coordinate.latitude, longitude: shop2.mapItem.placemark.coordinate.longitude)
                return userLocation.distance(from: loc1) < userLocation.distance(from: loc2)
            }

        case .rating:
            return results.sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }

        case .name:
            return results.sorted { ($0.mapItem.name ?? "") < ($1.mapItem.name ?? "") }
        }
    }

    func updateFilter(_ filter: ShopFilter) {
        currentFilter = filter
        applyFilters()
    }

    // MARK: - Search History
    private func addToSearchHistory(_ query: String) {
        guard !query.isEmpty else { return }

        // Remove if already exists
        searchHistory.removeAll { $0 == query }

        // Add to beginning
        searchHistory.insert(query, at: 0)

        // Keep only last N searches
        if searchHistory.count > maxHistoryCount {
            searchHistory = Array(searchHistory.prefix(maxHistoryCount))
        }

        // Save to UserDefaults
        UserDefaults.standard.set(searchHistory, forKey: "MapSearchHistory")
    }

    func loadSearchHistory() {
        if let history = UserDefaults.standard.stringArray(forKey: "MapSearchHistory") {
            searchHistory = history
        }
    }

    func clearSearchHistory() {
        searchHistory = []
        UserDefaults.standard.removeObject(forKey: "MapSearchHistory")
    }

    // MARK: - Favorites
    func toggleFavorite(for item: MKMapItem) {
        guard let identifier = item.name else { return }

        if favoriteLocations.contains(identifier) {
            favoriteLocations.remove(identifier)
        } else {
            favoriteLocations.insert(identifier)
        }

        saveFavorites()
    }

    func isFavorite(_ item: MKMapItem) -> Bool {
        guard let identifier = item.name else { return false }
        return favoriteLocations.contains(identifier)
    }

    private func saveFavorites() {
        let array = Array(favoriteLocations)
        UserDefaults.standard.set(array, forKey: "MapFavoriteLocations")
    }

    func loadFavorites() {
        if let favorites = UserDefaults.standard.stringArray(forKey: "MapFavoriteLocations") {
            favoriteLocations = Set(favorites)
        }
    }

    // MARK: - Route Calculation
    func calculateRoute(from source: CLLocationCoordinate2D, to destination: MKMapItem, completion: @escaping (MKRoute?) -> Void) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
        request.destination = destination
        request.transportType = .automobile
        request.requestsAlternateRoutes = false

        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            if let error = error {
                print("Route calculation error: \(error.localizedDescription)")
                completion(nil)
                return
            }

            completion(response?.routes.first)
        }
    }
}
