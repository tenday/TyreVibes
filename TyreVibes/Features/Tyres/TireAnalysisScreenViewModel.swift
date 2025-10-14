import SwiftUI
import Combine

class TireAnalysisScreenViewModel: ObservableObject {
    @Published var carImage: UIImage?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let vehicle: Vehicle
    private var cancellables = Set<AnyCancellable>()

    init(vehicle: Vehicle) {
        self.vehicle = vehicle
    }

    func fetchImage() {
        guard let make = vehicle.make, let modelFamily = vehicle.model, let year = vehicle.saleStart, let paintId = vehicle.color else {
            errorMessage = "Vehicle data is incomplete."
            return
        }

        self.isLoading = true

        // Using angle 1 for top-down view based on imagin.studio documentation
        VehicleImageService.fetchVehicleImage(make: make, modelFamily: modelFamily, year: year, paintId: paintId, angle: 1, plate: "") { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let image):
                    self?.carImage = image
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
}