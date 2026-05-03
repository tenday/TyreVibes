#if os(visionOS)
import Foundation
import SwiftUI

struct VisionTyreSnapshot: Identifiable, Hashable {
    enum HealthState: String {
        case unknown
        case optimal
        case monitor
        case critical

        var title: String {
            switch self {
            case .unknown:
                return "Non analizzato"
            case .optimal:
                return "Ottimo"
            case .monitor:
                return "Da monitorare"
            case .critical:
                return "Critico"
            }
        }

        var tint: Color {
            switch self {
            case .unknown:
                return .gray
            case .optimal:
                return .green
            case .monitor:
                return .orange
            case .critical:
                return .red
            }
        }
    }

    let id = UUID()
    let position: String
    let model: String
    let treadDepthMillimeters: Double
    let pressureBar: Double
    let healthState: HealthState
}

struct VisionVehicleImageProfile: Hashable {
    static let garageAngle = 214
    static let defaultAngles = Array(200...231)

    let make: String
    let modelFamily: String
    let year: String
    let paintId: String

    var garageImageURL: URL? {
        imageURL(angle: Self.garageAngle)
    }

    func imageURL(angle: Int) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "cdn.imagin.studio"
        components.path = "/getImage"
        components.queryItems = [
            URLQueryItem(name: "customer", value: "img"),
            URLQueryItem(name: "make", value: make),
            URLQueryItem(name: "modelFamily", value: modelFamily),
            URLQueryItem(name: "paintId", value: Self.normalizedPaintId(from: paintId)),
            URLQueryItem(name: "angle", value: String(angle)),
            URLQueryItem(name: "modelYear", value: year),
            URLQueryItem(name: "fileType", value: "webp"),
            URLQueryItem(name: "zoomType", value: "relative"),
            URLQueryItem(name: "tailoring", value: "empty")
        ]
        return components.url
    }

    private static func normalizedPaintId(from raw: String) -> String {
        let upper = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: .current)
            .uppercased()

        guard !upper.isEmpty else { return "BLACK" }

        if upper.range(of: #"^(PSPC|MZ|NZ)[A-Z0-9]*$"#, options: .regularExpression) != nil {
            return upper
        }

        let hex = upper.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if hex.range(of: #"^[A-F0-9]{6}$"#, options: .regularExpression) != nil {
            return hex
        }

        let normalized = upper
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")

        let palette: [(keywords: [String], paint: String)] = [
            (["BIANCO", "WHITE", "PERLA", "PEARL"], "WHITE"),
            (["NERO", "BLACK", "NOIR"], "BLACK"),
            (["GRIGIO", "GREY", "GRAY", "ARGENTO", "SILVER", "ANTRACITE"], "GRAY"),
            (["ROSSO", "RED", "BORDEAUX", "RUBINO"], "RED"),
            (["BLU", "BLUE", "AZZURRO", "NAVY"], "BLUE"),
            (["VERDE", "GREEN"], "GREEN"),
            (["GIALLO", "YELLOW"], "YELLOW"),
            (["ARANCIO", "ARANCIONE", "ORANGE"], "ORANGE"),
            (["MARRONE", "BROWN", "BRONZO"], "BROWN"),
            (["BEIGE", "CREMA", "SABBIA"], "BEIGE"),
            (["ORO", "GOLD"], "GOLD"),
            (["VIOLA", "PURPLE", "LILLA"], "PURPLE")
        ]

        for entry in palette where entry.keywords.contains(where: { normalized.contains($0) }) {
            return entry.paint
        }

        let compact = normalized.components(separatedBy: .whitespacesAndNewlines).joined()
        return compact.isEmpty ? "BLACK" : compact
    }
}

struct VisionVehicleSnapshot: Identifiable, Hashable {
    let id: String
    let name: String
    let plate: String
    let bodyColor: Color
    let imageProfile: VisionVehicleImageProfile?
    let tyres: [VisionTyreSnapshot]

    var healthState: VisionTyreSnapshot.HealthState {
        if tyres.contains(where: { $0.healthState == .critical }) {
            return .critical
        }
        if tyres.contains(where: { $0.healthState == .monitor }) {
            return .monitor
        }
        if tyres.allSatisfy({ $0.healthState == .unknown }) {
            return .unknown
        }
        return .optimal
    }

    var minimumTreadDepthMillimeters: Double {
        tyres.map(\.treadDepthMillimeters).min() ?? 0
    }

    var averagePressureBar: Double {
        guard !tyres.isEmpty else { return 0 }
        return tyres.map(\.pressureBar).reduce(0, +) / Double(tyres.count)
    }
}
#endif
