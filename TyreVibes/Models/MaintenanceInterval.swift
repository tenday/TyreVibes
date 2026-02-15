import Foundation

struct MaintenanceInterval: Identifiable, Codable {
    let id: String
    let maintenanceType: MaintenanceSchedule.MaintenanceType
    let kmInterval: Int?
    let monthsInterval: Int?
    let isCustom: Bool
    let vehicleId: Int?

    init(
        id: String = UUID().uuidString,
        maintenanceType: MaintenanceSchedule.MaintenanceType,
        kmInterval: Int? = nil,
        monthsInterval: Int? = nil,
        isCustom: Bool = false,
        vehicleId: Int? = nil
    ) {
        self.id = id
        self.maintenanceType = maintenanceType
        self.kmInterval = kmInterval
        self.monthsInterval = monthsInterval
        self.isCustom = isCustom
        self.vehicleId = vehicleId
    }

    /// Default maintenance intervals for common vehicle services
    static let defaults: [MaintenanceInterval] = [
        // Motore
        MaintenanceInterval(maintenanceType: .oilChange, kmInterval: 15000, monthsInterval: 12),
        MaintenanceInterval(maintenanceType: .sparkPlugs, kmInterval: 30000, monthsInterval: 36),
        MaintenanceInterval(maintenanceType: .timingBelt, kmInterval: 120000, monthsInterval: 72),
        MaintenanceInterval(maintenanceType: .clutch, kmInterval: 100000, monthsInterval: nil),
        MaintenanceInterval(maintenanceType: .generalService, kmInterval: 30000, monthsInterval: 24),
        // Freni
        MaintenanceInterval(maintenanceType: .brakePads, kmInterval: 40000, monthsInterval: 36),
        MaintenanceInterval(maintenanceType: .brakeDiscs, kmInterval: 80000, monthsInterval: 60),
        // Liquidi
        MaintenanceInterval(maintenanceType: .brakeFluid, kmInterval: nil, monthsInterval: 24),
        MaintenanceInterval(maintenanceType: .coolant, kmInterval: 60000, monthsInterval: 48),
        MaintenanceInterval(maintenanceType: .washerFluid, kmInterval: nil, monthsInterval: 3),
        // Filtri
        MaintenanceInterval(maintenanceType: .airFilter, kmInterval: 30000, monthsInterval: 24),
        MaintenanceInterval(maintenanceType: .oilFilter, kmInterval: 15000, monthsInterval: 12),
        MaintenanceInterval(maintenanceType: .fuelFilter, kmInterval: 60000, monthsInterval: 48),
        MaintenanceInterval(maintenanceType: .cabinFilter, kmInterval: 20000, monthsInterval: 12),
        // Altro
        MaintenanceInterval(maintenanceType: .battery, kmInterval: nil, monthsInterval: 48),
        MaintenanceInterval(maintenanceType: .shockAbsorbers, kmInterval: 80000, monthsInterval: 60),
        // Pneumatici
        MaintenanceInterval(maintenanceType: .rotation, kmInterval: 10000, monthsInterval: 6),
        MaintenanceInterval(maintenanceType: .pressureCheck, kmInterval: nil, monthsInterval: 1),
        MaintenanceInterval(maintenanceType: .alignment, kmInterval: 20000, monthsInterval: 12),
        MaintenanceInterval(maintenanceType: .balancing, kmInterval: 20000, monthsInterval: 12),
        MaintenanceInterval(maintenanceType: .seasonalChange, kmInterval: nil, monthsInterval: 6),
        MaintenanceInterval(maintenanceType: .inspection, kmInterval: 20000, monthsInterval: 12),
    ]
}
