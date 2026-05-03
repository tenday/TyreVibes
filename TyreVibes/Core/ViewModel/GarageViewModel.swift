import Foundation
import SwiftUI
import Supabase

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
    @Published var vehicleThumbnails: [Int: UIImage] = [:]

    private let authService = AuthService()
    static let apiConfig = PlateAPIService.apiConfig
    private var thumbnailTasks: [Int: Task<Void, Never>] = [:]

    private struct VehiclesEnvelope: Decodable {
        let vehicles: [VehicleResponse]?
        let data: [VehicleResponse]?
    }

    private struct APIErrorResponse: Decodable {
        let message: String?
        let error: String?
    }


    func fetchCars() async {
        // Show cached vehicles first if available, but only if not loading
        var didLoadCachedVehicles = false
        if isLoading, let cachedData = UserDefaults.standard.data(forKey: "cachedVehicles") {
            if let cachedVehicles = try? JSONDecoder().decode([VehicleResponse].self, from: cachedData) {
                vehicles = cachedVehicles
                loadVehicleThumbnails(for: cachedVehicles)
                didLoadCachedVehicles = true
            } else {
                UserDefaults.standard.removeObject(forKey: "cachedVehicles")
            }
        }
        
        do {
            guard let userId = await AuthService.currentUserId, !userId.isEmpty else {
                print("Error fetching cars: userId not found")
                vehicles = []
                isLoading = false
                return
            }

            guard let baseURL = GarageViewModel.apiConfig["BASE_URL"] as? String else {
                print("API_BASE_URL not found in Info.plist")
                isLoading = false
                return
            }
            guard let url = URL(string: "\(baseURL)/v1/vehicles/\(userId)?includeImages=false") else {
                print("Invalid URL")
                isLoading = false
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"

            // Add JWT token
            await AuthTokenHelper.addAuthHeader(to: &request)

            let (data, response) = try await URLSession.tyreVibesShared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
                let message = apiError?.message ?? apiError?.error ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                throw NSError(
                    domain: "GarageViewModel",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: message]
                )
            }

            let decodedResponse = try decodeVehicles(from: data)
            
            // Force a clean update by creating a new array
            vehicles = decodedResponse
            UserDefaults.standard.set(data, forKey: "cachedVehicles")
            loadVehicleThumbnails(for: decodedResponse)
            isLoading = false
        } catch {
            // Handle the error appropriately, e.g., show an alert to the user
            print("Error fetching cars: \(error)")
            if !didLoadCachedVehicles {
                vehicles = []
            }
            isLoading = false
        }
    }

    private func loadVehicleThumbnails(for vehicles: [VehicleResponse]) {
        let vehicleIds = Set(vehicles.map { $0.vehicle.id })
        vehicleThumbnails = vehicleThumbnails.filter { vehicleIds.contains($0.key) }

        for vehicle in vehicles {
            let vehicleId = vehicle.vehicle.id
            if vehicleThumbnails[vehicleId] != nil || thumbnailTasks[vehicleId] != nil {
                continue
            }

            thumbnailTasks[vehicleId] = Task { [weak self] in
                guard let self else { return }
                defer {
                    Task { @MainActor in
                        self.thumbnailTasks[vehicleId] = nil
                    }
                }

                guard let thumbnail = await self.fetchVehicleThumbnail(vehicleId: vehicleId) else {
                    return
                }

                await MainActor.run {
                    self.vehicleThumbnails[vehicleId] = thumbnail
                }
            }
        }
    }

    private func fetchVehicleThumbnail(vehicleId: Int) async -> UIImage? {
        guard let baseURL = GarageViewModel.apiConfig["BASE_URL"] as? String,
              let url = URL(string: "\(baseURL)/v1/vehicles/\(vehicleId)/image/thumbnail?v=2") else {
            return nil
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = NetworkTimeout.quickLookup
        config.timeoutIntervalForResource = NetworkTimeout.externalAPI
        config.requestCachePolicy = .returnCacheDataElseLoad
        let session = URLSession(configuration: config)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        guard await AuthTokenHelper.addAuthHeader(to: &request) else {
            return nil
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let image = UIImage(data: data) else {
                return nil
            }
            return image.trimmedTransparentPixels(threshold: 5)
        } catch {
            print("Error fetching vehicle thumbnail \(vehicleId): \(error)")
            return nil
        }
    }

    private func decodeVehicles(from data: Data) throws -> [VehicleResponse] {
        let decoder = JSONDecoder()

        if let vehicles = try? decoder.decode([VehicleResponse].self, from: data) {
            return vehicles
        }

        let envelope = try decoder.decode(VehiclesEnvelope.self, from: data)
        return envelope.vehicles ?? envelope.data ?? []
    }

    func showDetails(for vehicle: VehicleResponse) {
        selectedVehicle = vehicle
        showCarDetails = true
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

                // Add JWT token
                await AuthTokenHelper.addAuthHeader(to: &request)

                let (_, response) = try await URLSession.tyreVibesShared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        vehicles.removeAll { $0.vehicle.id == vehicle.id }
                        vehicleThumbnails[vehicle.id] = nil
                    }
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
