import Foundation
import SwiftUI

@MainActor
class GarageViewModel: ObservableObject {
    @Published var cars: [Car] = []

    private let authService = AuthService()

    func fetchCars() {
        Task {
            do {
                cars = try await authService.getVehiclesForCurrentUser()
            } catch {
                // Handle the error appropriately, e.g., show an alert to the user
                print("Error fetching cars: \(error)")
            }
        }
    }

    func deleteCar(_ car: Car) {
        Task {
            do {
                try await authService.deleteCar(withId: car.id)
                // Remove the car from the local array
                cars.removeAll { $0.id == car.id }
            } catch {
                // Handle the error appropriately
                print("Error deleting car: \(error)")
            }
        }
    }
}
