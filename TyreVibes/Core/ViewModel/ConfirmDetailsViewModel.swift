import Foundation
import SwiftUI

@MainActor
class ConfirmDetailsViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var alertItem: AlertItem?
    @Published var didSavePlate = false
    @Published var vehicleImage: UIImage?
    @Published var vehicleImageColored: UIImage?
    @Published var vehicleImageOriginal: UIImage?

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
    
    public func associateVehicleWithUser(vehicleId: Int) async {
        isLoading = true
        let userId = await AuthService.currentUserId
        guard let userId = userId else {
            print("userId not found")
            return
        }
        Task {
            do {
                let (imageBase64, mimeType) = try await plateAPIService.associateVehicle2User(vehicleId: vehicleId, userId: userId)
                if let base64 = imageBase64, let mime = mimeType,
                   let data = Data(base64Encoded: base64),
                   let uiImage = UIImage(data: data) {
                    self.vehicleImage = uiImage
                }
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
                case .alreadyInGarage:
                    self.alertItem = AlertItem(title: "Success", message: "Veicolo presente in garage.")
                }
            } catch {
                self.didSavePlate = false
                self.alertItem = AlertItem(title: "Error", message: error.localizedDescription)
            }
            self.isLoading = false
        }
    }
    
    

    func savePlate(plateData: PlateData, color: String, angle: Int) async {
        isLoading = true
        Task {
            VehicleImageService.fetchVehicleImage(
                make: plateData.make ?? "",
                modelFamily: plateData.model ?? "",
                year: plateData.year ?? "",
                paintId: color,
                angle: angle,
                plate: plateData.plate
            ) { result in
                switch result {
                case .success(let imgColored):
                    Task { @MainActor in
                        let safeImageColored = self.ensureRenderable(imgColored)
                        self.vehicleImageColored = safeImageColored
                        VehicleImageService.fetchVehicleImage(
                            make: plateData.make ?? "",
                            modelFamily: plateData.model ?? "",
                            year: plateData.year ?? "",
                            paintId: "",
                            angle: angle,
                            plate: plateData.plate
                        ) { result in
                            switch result {
                            case .success(let imgOriginal):
                                Task { @MainActor in
                                    let safeImageOriginal = self.ensureRenderable(imgOriginal)
                                    self.vehicleImageOriginal = safeImageOriginal
                                    VehicleImageService.fetchVehicleImage(
                                        make: plateData.make ?? "",
                                        modelFamily: plateData.model ?? "",
                                        year: plateData.year ?? "",
                                        paintId: color,
                                        angle: 12,
                                        plate: plateData.plate
                                    ) { safeImageColored12 in
                                        switch safeImageColored12 {
                                        case .success(let imageColored12Result):
                                            Task { @MainActor in
                                                let imageColored12 = self.ensureRenderable(imageColored12Result)
                                                VehicleImageService.fetchVehicleImage(
                                                    make: plateData.make ?? "",
                                                    modelFamily: plateData.model ?? "",
                                                    year: plateData.year ?? "",
                                                    paintId: "",
                                                    angle: 12,
                                                    plate: plateData.plate
                                                ) { imageNoColor12 in
                                                    switch imageNoColor12 {
                                                    case .success(let noColorImage12):
                                                        Task { @MainActor in
                                                            let ImageNeutral12 = self.ensureRenderable(noColorImage12)
                                                            do {
                                                                try await self.plateAPIService.savePlate(
                                                                    plateData: plateData,
                                                                    color: color,
                                                                    userId: AuthService.currentUserId ?? "",
                                                                    images: [safeImageColored, safeImageOriginal, imageColored12, ImageNeutral12],
                                                                    imagesColor: [color, "", color , ""]
                                                                )
                                                                self.vehicleImage = safeImageColored
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
                                                                case .alreadyInGarage:
                                                                    self.alertItem = AlertItem(title: "Error", message: "Veicolo già presente nel tuo garage.")
                                                                }
                                                            } catch {
                                                                self.didSavePlate = false
                                                                self.alertItem = AlertItem(title: "Error", message: error.localizedDescription)
                                                            }
                                                            self.isLoading = false
                                                        }
                                                    case .failure(let err):
                                                        Task { @MainActor in
                                                            print("Errore nel recupero immagine -45: \(err.localizedDescription)")
                                                            self.didSavePlate = false
                                                            self.alertItem = AlertItem(title: "Errore immagine", message: err.localizedDescription)
                                                            self.isLoading = false
                                                        }
                                                    }
                                                }
                                            }
                                        case .failure(let err):
                                            Task { @MainActor in
                                                print("Errore nel recupero immagine +45: \(err.localizedDescription)")
                                                self.didSavePlate = false
                                                self.alertItem = AlertItem(title: "Errore immagine", message: err.localizedDescription)
                                                self.isLoading = false
                                            }
                                        }
                                    }
                                }
                            case .failure(let err):
                                Task { @MainActor in
                                    print("Errore nel recupero immagine originale: \(err.localizedDescription)")
                                    self.vehicleImageOriginal = nil
                                    self.didSavePlate = false
                                    self.alertItem = AlertItem(title: "Errore immagine", message: err.localizedDescription)
                                    self.isLoading = false
                                }
                            }
                        }
                    }
                case .failure(let err):
                    Task { @MainActor in
                        print("Errore nel recupero immagine: \(err.localizedDescription)")
                        self.vehicleImageColored = nil
                        self.didSavePlate = false
                        self.alertItem = AlertItem(title: "Errore immagine", message: err.localizedDescription)
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    
}
