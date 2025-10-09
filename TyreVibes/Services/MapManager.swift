import Foundation
import MapKit

class MapManager: NSObject, ObservableObject {

    @Published var searchResults: [MKMapItem] = []

    func searchPlaces(query: String, region: MKCoordinateRegion) {
        let searchRequest = MKLocalSearch.Request()
        // Combine user's query with specific categories
        searchRequest.naturalLanguageQuery = "\(query) gommista officina"
        searchRequest.region = region

        let search = MKLocalSearch(request: searchRequest)
        search.start { [weak self] (response, error) in
            guard let response = response else {
                if let error = error {
                    print("Error during search: \(error.localizedDescription)")
                }
                self?.searchResults = []
                return
            }

            DispatchQueue.main.async {
                self?.searchResults = response.mapItems
            }
        }
    }

}