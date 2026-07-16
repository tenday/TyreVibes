import Foundation

enum FacileVehicleResponseParserError: LocalizedError {
    case invalidJSON
    case missingVehicle
    case missingIdentity

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Risposta veicolo non valida"
        case .missingVehicle:
            return "Veicolo non presente nella risposta"
        case .missingIdentity:
            return "Dati identificativi del veicolo mancanti"
        }
    }
}

struct FacileVehicleData: Sendable {
    var make = ""
    var model = ""
    var modelDetails = ""
    var registrationDate = ""
    var powerKW = ""
    var powerCV = ""
    var displacementCC = ""
    var fuelType = ""

    var dictionary: [String: Any] {
        [
            "make": make,
            "model": model,
            "modelDetails": modelDetails,
            "registrationDate": registrationDate,
            "powerKW": powerKW,
            "powerCV": powerCV,
            "displacementCC": displacementCC,
            "fuelType": fuelType
        ]
    }
}

enum FacileVehicleResponseParser {
    static func parse(data: Data) throws -> FacileVehicleData {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let right = root["right"] as? [String: Any],
            let vehicle = right["vehicle"] as? [String: Any]
        else {
            if (try? JSONSerialization.jsonObject(with: data)) == nil {
                throw FacileVehicleResponseParserError.invalidJSON
            }
            throw FacileVehicleResponseParserError.missingVehicle
        }

        let details = (vehicle["car"] as? [String: Any])
            ?? (vehicle["van"] as? [String: Any])
        guard let details else {
            throw FacileVehicleResponseParserError.missingVehicle
        }

        var result = FacileVehicleData()
        result.make = nestedName(details["make"])
        result.model = nestedName(details["model"])

        if let registration = vehicle["registration"] as? [String: Any] {
            result.registrationDate = normalizedRegistrationDate(stringValue(registration["date"]))
        }

        if let equipment = details["equipment"] as? [String: Any] {
            result.modelDetails = stringValue(equipment["name"])
            result.powerKW = stringValue(equipment["powerKw"])
            result.powerCV = stringValue(equipment["powerHp"])
            result.displacementCC = stringValue(equipment["displacement"])
            result.fuelType = normalizedFuel(stringValue(equipment["fuelType"]))
        }

        guard !result.make.isEmpty || !result.model.isEmpty || !result.modelDetails.isEmpty else {
            throw FacileVehicleResponseParserError.missingIdentity
        }
        return result
    }

    private static func nestedName(_ value: Any?) -> String {
        guard let dictionary = value as? [String: Any] else { return "" }
        return stringValue(dictionary["name"])
    }

    private static func stringValue(_ value: Any?) -> String {
        switch value {
        case let string as String:
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        case let number as NSNumber:
            return number.stringValue
        default:
            return ""
        }
    }

    private static func normalizedFuel(_ value: String) -> String {
        switch value.lowercased() {
        case "petrol", "benzina", "b":
            return "Benzina"
        case "diesel", "d":
            return "Diesel"
        case "hybrid", "ibrida", "i", "h":
            return "Ibrida"
        case "electric", "elettrica", "e":
            return "Elettrica"
        case "lpg", "gpl", "g", "l":
            return "GPL"
        case "methane", "metano", "m":
            return "Metano"
        default:
            return value
        }
    }

    private static func normalizedRegistrationDate(_ value: String) -> String {
        guard let range = value.range(
            of: #"^\d{4}-\d{2}-\d{2}"#,
            options: .regularExpression
        ) else {
            return value
        }
        return String(value[range])
    }
}
