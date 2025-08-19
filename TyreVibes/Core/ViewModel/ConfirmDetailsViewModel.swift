import Foundation
import SwiftUI

@MainActor
class ConfirmDetailsViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var alertItem: AlertItem?
    @Published var didSavePlate = false

    private let plateAPIService = PlateAPIService()

    func savePlate(plateData: PlateData, color: Color) {
        isLoading = true
        Task {
            do {
                try await plateAPIService.savePlate(plateData: plateData, color: color)
                isLoading = false
                didSavePlate = true
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
