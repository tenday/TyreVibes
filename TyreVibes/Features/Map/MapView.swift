import SwiftUI
import MapKit

struct MapView: View {
    @StateObject private var mapManager = MapManager()
    @State private var cameraPosition: MapCameraPosition
    @State private var searchText = ""

    init() {
        // Initialize the camera position centered on a default location.
        let center = CLLocationCoordinate2D(latitude: 41.9028, longitude: 12.4964) // Rome
        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(center: center, latitudinalMeters: 500000, longitudinalMeters: 500000)))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $cameraPosition) {
                // Display search results
                ForEach(mapManager.searchResults, id: \.self) { item in
                    Marker(item.name ?? "Workshop", coordinate: item.placemark.coordinate)
                }
            }
            .edgesIgnoringSafeArea(.top)

            HStack {
                TextField("Search for tire shops or workshops...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.leading)

                Button(action: {
                    if let region = cameraPosition.region {
                        mapManager.searchPlaces(query: searchText, region: region)
                        // Dismiss keyboard
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }) {
                    Image(systemName: "magnifyingglass")
                        .padding(.horizontal)
                }
            }
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.8))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.top, 50)
        }
        .onChange(of: mapManager.searchResults) {
            if !mapManager.searchResults.isEmpty {
                let coordinates = mapManager.searchResults.map { $0.placemark.coordinate }
                cameraPosition = .region(regionFor(coordinates: coordinates))
            }
        }
    }

    /// Calculates a region that encompasses a list of coordinates.
    private func regionFor(coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        if coordinates.isEmpty {
            return MKCoordinateRegion()
        }

        if coordinates.count == 1 {
            return MKCoordinateRegion(center: coordinates.first!, latitudinalMeters: 10000, longitudinalMeters: 10000)
        }

        var minLat: CLLocationDegrees = 90.0
        var maxLat: CLLocationDegrees = -90.0
        var minLon: CLLocationDegrees = 180.0
        var maxLon: CLLocationDegrees = -180.0

        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        // Add some padding to the span
        let span = MKCoordinateSpan(latitudeDelta: (maxLat - minLat) * 1.4, longitudeDelta: (maxLon - minLon) * 1.4)

        return MKCoordinateRegion(center: center, span: span)
    }
}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView()
    }
}