import Foundation
import SwiftUI

struct VehicleResponse: Codable, Hashable {
    let vehicle: Vehicle
    let plate: Plate?
    let image: VehicleImage?
    let tyres: [VehicleTyre]?
    let revisions: [VehicleRevision]?
    let insurances: [VehicleInsurance]?
}

@MainActor
class GarageViewModel: ObservableObject {
    @Published var vehicles: [VehicleResponse] = []
    @Published var isLoading = true
    @Published var showCarDetails = false
    @Published var selectedVehicle: VehicleResponse?

    private let authService = AuthService()
    static let apiConfig = PlateAPIService.apiConfig
    

    func fetchCars() async {
        let startTime = Date()

        // Show cached vehicles first if available, but only if not loading
        if isLoading, let cachedData = UserDefaults.standard.data(forKey: "cachedVehicles") {
            if let cachedVehicles = try? JSONDecoder().decode([VehicleResponse].self, from: cachedData) {
                vehicles = cachedVehicles
            }
        }

        do {
            let userId = await AuthService.currentUserId ?? ""

            guard let baseURL = GarageViewModel.apiConfig["BASE_URL"] as? String else {
                print("API_BASE_URL not found in Info.plist")
                return
            }
            guard let url = URL(string: "\(baseURL)/v1/vehicles/\(userId)") else {
                print("Invalid URL")
                return
            }
            let (data, _) = try await URLSession.shared.data(from: url)
            // Save raw data to UserDefaults before decoding
            UserDefaults.standard.set(data, forKey: "cachedVehicles")
            let decodedResponse = try JSONDecoder().decode([VehicleResponse].self, from: data)

            // Force a clean update by creating a new array
            vehicles = decodedResponse
            isLoading = false

            // Track screen loaded
            let duration = Date().timeIntervalSince(startTime)
            await AnalyticsManager.shared.track(
                .screenLoaded(name: "GarageScreen", duration: duration, itemCount: vehicles.count)
            )
        } catch {
            // Handle the error appropriately, e.g., show an alert to the user
            print("Error fetching cars: \(error)")
            vehicles = []
            isLoading = false

            // Track error
            await AnalyticsManager.shared.track(
                .errorOccurred(error: error.localizedDescription, screen: "GarageScreen", context: [:])
            )
        }
    }

    func showDetails(for vehicle: VehicleResponse) {
        selectedVehicle = vehicle
        showCarDetails = true

        // Track vehicle viewed
        Task {
            await AnalyticsManager.shared.track(
                .vehicleViewed(vehicleId: vehicle.vehicle.id)
            )
        }
    }

    func deleteCar(_ vehicle: Vehicle) {
        Task {
            do {
                guard let baseURL = GarageViewModel.apiConfig["BASE_URL"] as? String else {
                    print("BASE_URL not found")
                    return
                }
                let userId = await AuthService.currentUserId
                guard let userId = userId else {
                    print("userId not found")
                    return
                }

                guard let url = URL(string: "\(baseURL)/v1/vehicles/\(vehicle.id)/user/\(userId)") else {
                    print("Invalid URL")
                    return
                }

                var request = URLRequest(url: url)
                request.httpMethod = "DELETE"

                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        vehicles.removeAll { $0.vehicle.id == vehicle.id }
                    }
                    if let updatedData = try? JSONEncoder().encode(vehicles) {
                        UserDefaults.standard.set(updatedData, forKey: "cachedVehicles")
                    }

                    // Track vehicle deleted
                    await AnalyticsManager.shared.track(
                        .vehicleDeleted(vehicleId: vehicle.id, vehicleAge: 0)
                    )
                } else {
                    print("Errore del server durante la rimozione dell'associazione")
                }
            } catch {
                print("Error deleting car: \(error)")

                // Track error
                await AnalyticsManager.shared.track(
                    .errorOccurred(error: error.localizedDescription, screen: "GarageScreen", context: ["action": "delete_vehicle"])
                )
            }
        }
    }
}
