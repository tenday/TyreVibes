import Foundation

struct Vehicle: Identifiable, Codable, Hashable {
    let id: Int
    let modelDetail: String?
    let engine: String?
    let make: String?
    let model: String?
    let version: String?
    let fuelType: String?
    let displacementCC: Int?
    let powerCV: Int?
    let powerKW: String?
    let emissionClass: String?
    let gearbox: String?
    let maxSpeed: String?
    let bodyType: String?
    let doors: String?
    let seats: String?
    let consumption: String?
    let traction: String?
    let saleStart: String?
    let saleEnd: String?
    let color: String?
    let vin: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case modelDetail = "model_detail"
        case engine
        case make
        case model
        case version
        case fuelType = "fuel_type"
        case displacementCC = "displacement_cc"
        case powerCV = "power_cv"
        case powerKW = "power_kw"
        case emissionClass = "emission_class"
        case gearbox
        case maxSpeed = "max_speed"
        case bodyType = "body_type"
        case doors
        case seats
        case consumption
        case traction
        case saleStart = "sale_start"
        case saleEnd = "sale_end"
        case color
        case vin
        case createdAt = "created_at"
    }
}

struct Plate: Codable, Identifiable, Hashable {
    let id: Int
    let plateNumber: String
    let registrationDate: String?
    let year: Int?
    let month :Int?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case plateNumber = "plate_number"
        case registrationDate = "registration_date"
        case year
        case month
        case createdAt = "created_at"
    }
    
}

struct VehicleImage: Codable, Identifiable, Hashable {
    let id: Int
    let mimeType: String?
    let color: String?
    let fileName: String?
    let fileSize: Int?
    let sha256: String?
    let imageBase64: String?

    enum CodingKeys: String, CodingKey {
        case id
        case mimeType = "mime_type"
        case color
        case fileName = "file_name"
        case fileSize = "file_size"
        case sha256
        case imageBase64 = "image_base64"
    }
}

struct VehicleTyre: Codable, Identifiable, Hashable {
    let id: Int
    let width: Int?
    let diameter: Int?
    let ratio: Int?
    let speedIndex: String?
    let loadIndex: String?
    let sizeLabel: String?
    let setId: Int? // Per identificare il set di appartenenza (es. 1 = anteriore, 2 = posteriore)
    let setName: String? // Nome del set (es. "Anteriore", "Posteriore", "Set Standard")

    enum CodingKeys: String, CodingKey {
        case id
        case width
        case diameter
        case ratio
        case speedIndex = "speed_index"
        case loadIndex = "load_index"
        case sizeLabel = "size_label"
        case setId = "set_id"
        case setName = "set_name"
    }
}

struct VehicleRevision: Codable, Identifiable, Hashable {
    let id: Int
    let plateId: Int
    let kmRevisione: String?
    let dataRevisione: String?
    let esitoRevisione: String?

    enum CodingKeys: String, CodingKey {
        case id
        case plateId = "plate_id"
        case kmRevisione
        case dataRevisione
        case esitoRevisione
    }
}

struct VehicleInsurance: Codable, Identifiable, Hashable {
    let id: Int
    let plateId: Int
    let rcaCompany: String?
    let rcaPolicyNumber: String?
    let rcaExpiry: String?
    let rcaInsurancePresent: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case plateId = "plate_id"
        case rcaCompany = "rca_company"
        case rcaPolicyNumber = "rca_policy_number"
        case rcaExpiry = "rca_expiry"
        case rcaInsurancePresent = "rca_insurance_present"
    }
}

// MARK: - Tyre Size Set
struct TyreSizeSet: Identifiable, Hashable {
    let id: Int
    let name: String
    let tyres: [VehicleTyre]
    let isDefault: Bool

    init(id: Int, name: String, tyres: [VehicleTyre], isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.tyres = tyres
        self.isDefault = isDefault
    }
}

// MARK: - Derived Info
extension Vehicle {
    /// Descrizione "intelligente" del motore quando il campo engine è mancante.
    /// Combina cilindrata (L), alimentazione e potenza come fallback.
    var smartEngineDescription: String? {
        func cleaned(_ value: String?) -> String? {
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
                return nil
            }
            return trimmed
        }

        if let engine = cleaned(engine) {
            return engine.uppercased()
        }

        var parts: [String] = []

        if let displacement = displacementCC, displacement > 0 {
            let liters = Double(displacement) / 1000.0
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = 1
            formatter.maximumFractionDigits = 1
            if let lit = formatter.string(from: NSNumber(value: liters)) {
                parts.append("\(lit)L")
            } else {
                parts.append("\(displacement) CC")
            }
        }

        if let fuel = cleaned(fuelType)?.uppercased() {
            parts.append(fuel)
        }

        if let power = powerCV, power > 0 {
            parts.append("\(power) CV")
        } else if let kw = cleaned(powerKW) {
            parts.append("\(kw.uppercased()) kW")
        }

        if !parts.isEmpty {
            return parts.joined(separator: " ")
        }

        if let version = cleaned(version)?.uppercased() ?? cleaned(modelDetail)?.uppercased() {
            return version
        }

        return nil
    }

    /// Descrizione "intelligente" del modello quando `model` è mancante.
    /// Pulisce il nome rimuovendo il brand e le indicazioni di serie/generazione numerica.
    /// Usa model -> version -> modelDetail come fallback.
    var smartModelDescription: String? {
        func cleaned(_ value: String?) -> String? {
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
                return nil
            }
            return trimmed
        }

        func normalizedModel(_ raw: String, make: String?) -> String? {
            var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }

            // Rimuovi il brand se è prefisso
            if let make = make?.trimmingCharacters(in: .whitespacesAndNewlines), !make.isEmpty {
                let lowerText = text.lowercased()
                let makeLower = make.lowercased()
                if lowerText.hasPrefix(makeLower + " ") {
                    text = String(text.dropFirst(make.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            // Normalizza spazi
            text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

            // Rimuovi indicazioni di serie/generazione numerica (ma mantieni "SERIE A" o simili)
            let patterns = [
                #"(?i)\b\d+\s*(?:a|ª)?\s*serie\b"#,      // "4a serie"
                #"(?i)\bserie\s*\d+(?:a|ª)?\b"#,         // "serie 4"
                #"(?i)\bserie\s*[ivx]+\b"#,              // "serie iv"
                #"(?i)\b[ivx]+\s*serie\b"#,              // "iv serie"
                #"(?i)\bmk\s*\d+\b"#                     // "mk4"
            ]
            for pattern in patterns {
                text = text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
            }

            text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty else { return nil }
            return text.uppercased()
        }

        if let model = cleaned(model), let normalized = normalizedModel(model, make: make) {
            return normalized
        }
        if let version = cleaned(version), let normalized = normalizedModel(version, make: make) {
            return normalized
        }
        if let detail = cleaned(modelDetail), let normalized = normalizedModel(detail, make: make) {
            return normalized
        }
        return nil
    }
}
