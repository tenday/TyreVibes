import Foundation
import SwiftUI

@MainActor
class ConfirmDetailsViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var alertItem: AlertItem?
    @Published var didSavePlate = false
    @Published var vehicleImage: UIImage?

    private let plateAPIService = PlateAPIService()

    func savePlate(plateData: PlateData, color: String) {
        isLoading = true
        Task {
            do {
                
                VehicleImageService.fetchVehicleImage(make: plateData.make ?? "", modelFamily: plateData.model ?? "", year: plateData.year ?? "", paintId: color) { result in
                    switch result {
                    case .success(let img):
                        DispatchQueue.main.async {
                            self.vehicleImage = img
                            self.didSavePlate = true
                        }
                    case .failure(let err):
                        print("Errore nel recupero immagine: \(err.localizedDescription)")
                        DispatchQueue.main.async {
                            self.vehicleImage = nil
                            self.didSavePlate = false
                        }
                    }
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                }
            } catch {
                isLoading = false
                if let apiError = error as? PlateAPIError {
                    switch apiError {
                    case .invalidURL:
                        alertItem = AlertItem(title: "Error", message: "The API URL is invalid.")
                    case .requestFailed:
                        alertItem = AlertItem(title: "Error", message: "The network request failed.")
                    case .invalidResponse:
                        alertItem = AlertItem(title: "Error", message: "Received an invalid response from the server.")
                    case .serverError(_, let message):
                        alertItem = AlertItem(title: "Server Error", message: message)
                    case .plateNotFound:
                        alertItem = AlertItem(title: "Error", message: "Targa non trovata.")
                    }
                } else {
                    alertItem = AlertItem(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    
}
