import Foundation
import SwiftUI

@MainActor
class ConfirmDetailsViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var alertItem: AlertItem?
    @Published var didSavePlate = false
    @Published var vehicleImage: UIImage?

    private let plateAPIService = PlateAPIService()

    private func ensureRenderable(_ image: UIImage) -> UIImage {
        if image.cgImage != nil { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    func savePlate(plateData: PlateData, color: String) {
        isLoading = true
        Task {
            VehicleImageService.fetchVehicleImage(
                make: plateData.make ?? "",
                modelFamily: plateData.model ?? "",
                year: plateData.year ?? "",
                paintId: color,
                plate: plateData.plate
            ) { result in
                switch result {
                case .success(let img):
                    Task { @MainActor in
                        // Re-rasterizza (utile per immagini WEBP/CIImage senza cgImage)
                        let safeImage = self.ensureRenderable(img)
                        self.vehicleImage = safeImage
                        do {
                            try await self.plateAPIService.savePlate(
                                plateData: plateData,
                                color: color,
                                userId: AuthService.currentUserId ?? "",
                                image: safeImage
                            )
                            self.didSavePlate = true
                        } catch let apiError as PlateAPIError {
                            self.didSavePlate = false
                            switch apiError {
                            case .invalidURL:
                                self.alertItem = AlertItem(title: "Error", message: "The API URL is invalid.")
                            case .requestFailed:
                                self.alertItem = AlertItem(title: "Error", message: "The network request failed.")
                            case .invalidResponse:
                                self.alertItem = AlertItem(title: "Error", message: "Received an invalid response from the server.")
                            case .serverError(_, let message):
                                self.alertItem = AlertItem(title: "Server Error", message: message)
                            case .plateNotFound:
                                self.alertItem = AlertItem(title: "Error", message: "Targa non trovata.")
                            }
                        } catch {
                            self.didSavePlate = false
                            self.alertItem = AlertItem(title: "Error", message: error.localizedDescription)
                        }
                        self.isLoading = false
                    }

                case .failure(let err):
                    Task { @MainActor in
                        print("Errore nel recupero immagine: \(err.localizedDescription)")
                        self.vehicleImage = nil
                        self.didSavePlate = false
                        self.alertItem = AlertItem(title: "Errore immagine", message: err.localizedDescription)
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    
}
