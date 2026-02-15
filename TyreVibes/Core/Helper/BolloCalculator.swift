import Foundation

public struct BolloCalculationResult: Equatable {
    public let taxablePowerKW: Double
    public let baseBollo: Double
    public let superBollo: Double
    public let total: Double
    public let emissionClass: BolloCalculator.EmissionClass
    public let appliedRates: BolloCalculator.Rate

    public init(
        taxablePowerKW: Double,
        baseBollo: Double,
        superBollo: Double,
        total: Double,
        emissionClass: BolloCalculator.EmissionClass,
        appliedRates: BolloCalculator.Rate
    ) {
        self.taxablePowerKW = taxablePowerKW
        self.baseBollo = baseBollo
        self.superBollo = superBollo
        self.total = total
        self.emissionClass = emissionClass
        self.appliedRates = appliedRates
    }
}

public enum BolloCalculator {

    // MARK: - Emission Class Mapping
    public enum EmissionClass: Int, Comparable {
        case euro0 = 0
        case euro1 = 1
        case euro2 = 2
        case euro3 = 3
        case euro4 = 4
        case euro5 = 5
        case euro6 = 6

        public static func < (lhs: EmissionClass, rhs: EmissionClass) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        public static func from(_ raw: String?) -> EmissionClass? {
            guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !raw.isEmpty else {
                return nil
            }

            // Normalize variants such as "Euro 6d", "EURO6B" etc.
            let normalized = raw.replacingOccurrences(of: "euro", with: "")
                .replacingOccurrences(of: "eu", with: "")
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: "_", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Support "Euro 7" (and higher) by mapping to the latest available bracket.
            if let firstDigit = normalized.first(where: { $0.isNumber }),
               let value = Int(String(firstDigit)),
               value >= 6 {
                return .euro6
            }

            if normalized.contains("6") { return .euro6 }
            if normalized.contains("5") { return .euro5 }
            if normalized.contains("4") { return .euro4 }
            if normalized.contains("3") { return .euro3 }
            if normalized.contains("2") { return .euro2 }
            if normalized.contains("1") { return .euro1 }
            return .euro0
        }
    }

    // MARK: - Rate Table
    public struct Rate: Equatable {
        public let upTo100kW: Double
        public let over100kW: Double
    }

    private static let rateTable: [EmissionClass: Rate] = [
        .euro6: Rate(upTo100kW: 2.58, over100kW: 3.87),
        .euro5: Rate(upTo100kW: 2.58, over100kW: 3.87),
        .euro4: Rate(upTo100kW: 2.58, over100kW: 3.87),
        .euro3: Rate(upTo100kW: 2.70, over100kW: 4.05),
        .euro2: Rate(upTo100kW: 2.80, over100kW: 4.20),
        .euro1: Rate(upTo100kW: 3.00, over100kW: 4.50),
        .euro0: Rate(upTo100kW: 3.40, over100kW: 4.70)
    ]

    // MARK: - Public API

    /// Calcola l'importo del bollo auto (e superbollo, se applicabile).
    public static func calculateBollo(
        powerKW: Double,
        emissionClassRaw: String?,
        firstRegistrationDate: Date? = nil,
        referenceDate: Date = Date(),
        fuelType: String? = nil,
        isHistoricVehicle: Bool = false
    ) -> BolloCalculationResult {

        let sanitizedPower = max(0, powerKW)

        if isHistoricVehicle {
            return BolloCalculationResult(
                taxablePowerKW: sanitizedPower,
                baseBollo: 0,
                superBollo: 0,
                total: 0,
                emissionClass: .euro0,
                appliedRates: Rate(upTo100kW: 0, over100kW: 0)
            )
        }

        let normalizedFuel = fuelType?.lowercased()
        if let fuel = normalizedFuel, fuel.contains("electric") || fuel.contains("elettrico") {
            return BolloCalculationResult(
                taxablePowerKW: sanitizedPower,
                baseBollo: 0,
                superBollo: 0,
                total: 0,
                emissionClass: .euro6,
                appliedRates: Rate(upTo100kW: 0, over100kW: 0)
            )
        }

        let hybridDiscount: Double = {
            guard let fuel = normalizedFuel else { return 0 }
            let isHybrid = fuel.contains("ibrid") || fuel.contains("hybrid")
            guard isHybrid else { return 0 }
            if let firstRegistrationDate = firstRegistrationDate {
                let years = Calendar.current.dateComponents([.year], from: firstRegistrationDate, to: referenceDate).year ?? 0
                return years < 3 ? 0.5 : 0
            }
            return 0.5
        }()

        let emissionClass = EmissionClass.from(emissionClassRaw) ?? .euro6
        let rates = rateTable[emissionClass] ?? rateTable[.euro6]!

        let basePower = min(sanitizedPower, 100)
        let extraPower = max(0, sanitizedPower - 100)

        var baseAmount = (basePower * rates.upTo100kW) + (extraPower * rates.over100kW)
        baseAmount = applyDiscount(amount: baseAmount, discount: hybridDiscount)

        let superBolloAmount = calculateSuperBollo(
            powerKW: sanitizedPower,
            firstRegistrationDate: firstRegistrationDate,
            referenceDate: referenceDate
        )

        let total = roundToCents(baseAmount + superBolloAmount)

        return BolloCalculationResult(
            taxablePowerKW: sanitizedPower,
            baseBollo: roundToCents(baseAmount),
            superBollo: roundToCents(superBolloAmount),
            total: total,
            emissionClass: emissionClass,
            appliedRates: rates
        )
    }

    /// Convenience per PlateData.
    public static func calculateBollo(
        from plateData: PlateData,
        referenceDate: Date = Date(),
        isHistoricVehicle: Bool = false
    ) -> BolloCalculationResult? {
        guard let powerKW = extractPowerKW(from: plateData) else { return nil }

        let emission = plateData.emissionClass
        let firstRegistrationDate = plateData.registrationDate?.toDate()

        return calculateBollo(
            powerKW: powerKW,
            emissionClassRaw: emission,
            firstRegistrationDate: firstRegistrationDate,
            referenceDate: referenceDate,
            fuelType: plateData.fuelType,
            isHistoricVehicle: isHistoricVehicle
        )
    }

    // MARK: - Helpers

    private static func applyDiscount(amount: Double, discount: Double) -> Double {
        guard discount > 0 else { return amount }
        let bounded = min(max(discount, 0), 1)
        return amount * (1 - bounded)
    }

    private static func extractPowerKW(from plateData: PlateData) -> Double? {
        if let kwString = plateData.powerKW, let value = parseNumericValue(from: kwString) {
            return value
        }

        if let combined = plateData.powerCVKW, let value = parseKWFromCombined(combined) {
            return value
        }

        if let cvString = plateData.powerCV, let cv = parseNumericValue(from: cvString) {
            return cv * 0.735499
        }

        return nil
    }

    private static func parseKWFromCombined(_ raw: String) -> Double? {
        let sanitized = raw.replacingOccurrences(of: ",", with: ".").lowercased()

        if let kwMatch = matchNumber(in: sanitized, pattern: #"([0-9]+(?:\.[0-9]+)?)\s?k[w]"#) {
            return kwMatch
        }

        let numericComponents = sanitized
            .components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted)
            .compactMap { Double($0) }

        if let minValue = numericComponents.min() {
            return minValue
        }

        return nil
    }

    private static func matchNumber(in text: String, pattern: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges >= 2,
              let swiftRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return Double(String(text[swiftRange]))
    }

    private static func parseNumericValue(from raw: String) -> Double? {
        let sanitized = raw
            .replacingOccurrences(of: ",", with: ".")
            .components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted)
            .filter { !$0.isEmpty }

        guard let lastComponent = sanitized.last,
              let value = Double(lastComponent) else {
            return nil
        }

        return value
    }

    private static func calculateSuperBollo(
        powerKW: Double,
        firstRegistrationDate: Date?,
        referenceDate: Date
    ) -> Double {
        let taxableKW = max(0, powerKW - 185)
        guard taxableKW > 0 else { return 0 }

        let baseRate: Double = 20 // €/kW oltre i 185
        var multiplier: Double = 1.0

        if let firstRegistrationDate = firstRegistrationDate {
            let years = Calendar.current.dateComponents([.year], from: firstRegistrationDate, to: referenceDate).year ?? 0
            switch years {
            case ..<5:
                multiplier = 1.0
            case 5..<10:
                multiplier = 0.6
            case 10..<15:
                multiplier = 0.4
            case 15..<20:
                multiplier = 0.15
            default:
                multiplier = 0.0
            }
        }

        return roundToCents(taxableKW * baseRate * multiplier)
    }

    private static func roundToCents(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}

public extension BolloCalculator.EmissionClass {
    var description: String {
        switch self {
        case .euro6: return "Euro 6"
        case .euro5: return "Euro 5"
        case .euro4: return "Euro 4"
        case .euro3: return "Euro 3"
        case .euro2: return "Euro 2"
        case .euro1: return "Euro 1"
        case .euro0: return "Euro 0"
        }
    }
}

public extension BolloCalculationResult {
    var emissionClassDescription: String {
        emissionClass.description
    }
}

private extension String {
    func toDate(format: String = "yyyy-MM-dd") -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = format
        if let date = formatter.date(from: self) {
            return date
        }

        let alternativeFormats = ["dd/MM/yyyy", "yyyy-MM", "MM/yyyy", "yyyy"]
        for alternative in alternativeFormats {
            formatter.dateFormat = alternative
            if let date = formatter.date(from: self) {
                return date
            }
        }
        return nil
    }
}
