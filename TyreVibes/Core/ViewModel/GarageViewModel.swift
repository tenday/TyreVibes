import Foundation
import SwiftUI

struct VehicleResponse: Codable {
    let vehicle: Vehicle
    let plate: Plate?
    let image: VehicleImage?
    let tyres: [VehicleTyre]?
    let revisions: [VehicleRevision]?
}

@MainActor
class GarageViewModel: ObservableObject {
    @Published var vehicles: [VehicleResponse] = []
    @Published var isLoading = true

    private let authService = AuthService()
    static let apiConfig = PlateAPIService.apiConfig
    

    func fetchCars() async {
        // Show cached vehicles first if available
        if let cachedData = UserDefaults.standard.data(forKey: "cachedVehicles") {
            if let cachedVehicles = try? JSONDecoder().decode([VehicleResponse].self, from: cachedData) {
                vehicles = cachedVehicles
            }
        }
            Task {
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
                    vehicles = decodedResponse.map { $0 }
                    isLoading = false
                } catch {
                    // Handle the error appropriately, e.g., show an alert to the user
                    print("Error fetching cars: \(error)")
                }
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
                    vehicles.removeAll { $0.vehicle.id == vehicle.id }
                    if let updatedData = try? JSONEncoder().encode(vehicles) {
                        UserDefaults.standard.set(updatedData, forKey: "cachedVehicles")
                    }
                } else {
                    print("Errore del server durante la rimozione dell'associazione")
                }
            } catch {
                print("Error deleting car: \(error)")
            }
        }
    }
}
