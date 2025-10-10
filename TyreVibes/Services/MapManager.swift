import Foundation
import MapKit

class MapManager: NSObject, ObservableObject {

    @Published var searchResults: [MKMapItem] = []
    @Published var isSearching: Bool = false

    func searchPlaces(query: String, categoryHint: String?, region: MKCoordinateRegion) {
        let searchRequest = MKLocalSearch.Request()
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        var components: [String] = []

        if !trimmedQuery.isEmpty {
            components.append(trimmedQuery)
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

        DispatchQueue.main.async { [weak self] in
            self?.isSearching = true
        }

        let search = MKLocalSearch(request: searchRequest)
        search.start { [weak self] (response, error) in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if let response = response {
                    self.searchResults = response.mapItems
                } else {
                    if let error = error {
                        print("Error during search: \(error.localizedDescription)")
                    }
                    self.searchResults = []
                }

                self.isSearching = false
            }
        }
    }

}
