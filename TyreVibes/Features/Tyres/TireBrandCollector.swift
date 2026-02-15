import Foundation

/// Category metadata used to scope tire brands (vehicle type, service, etc.).
enum TireBrandCategory: String, CaseIterable, Hashable {
    case passenger
    case suv
    case truck
    case motorcycle
    case agriculture
    case industrial
    case ot
    case retread
}

/// Origin of the catalog entry to help explain where a brand was sourced from.
enum TireBrandSource: String {
    case association
    case eprel
    case commercial
    case community
}

/// A single canonical tire brand and its aliases/contexts.
struct TireBrandEntry: Hashable {
    let name: String
    let categories: Set<TireBrandCategory>
    let aliases: [String]
    let source: TireBrandSource
}

/// Centralized catalog that merges built-in brand lists and exposes helpers for OCR lookup.
final class TireBrandCollector {
    static let shared = TireBrandCollector()

    private(set) var entries: [TireBrandEntry]
    private let aliasLookup: [String: String]
    private let prioritizedAliases: [String]

    private init() {
        let catalog = Self.buildCatalog()
        self.entries = catalog
        self.aliasLookup = Self.buildAliasLookup(from: catalog)
        self.prioritizedAliases = Self.buildPrioritizedAliases(from: aliasLookup)
    }

    /// Returns the canonical names of every entry, optionally filtered by category.
    func canonicalBrandNames(filteredBy categories: Set<TireBrandCategory>? = nil) -> [String] {
        entries
            .filter { categories == nil || !$0.categories.isDisjoint(with: categories!) }
            .map { $0.name }
    }

    /// Aggregate all available brand strings, aliases included, respecting optional filters.
    func gatherAllBrands(includeAliases: Bool = true,
                         categories: Set<TireBrandCategory>? = nil,
                         sources: Set<TireBrandSource>? = nil) -> [String] {
        var strings = Set<String>()

        entries
            .filter { categories == nil || !$0.categories.isDisjoint(with: categories!) }
            .filter { sources == nil || sources!.contains($0.source) }
            .forEach { entry in
                strings.insert(entry.name)
                if includeAliases {
                    entry.aliases.forEach { strings.insert($0) }
                }
            }

        return strings.sorted()
    }

    /// Attempts to detect a brand (canonical name) inside the provided text.
    func detectBrand(in text: String) -> String? {
        let normalized = text.uppercased()
        for alias in prioritizedAliases {
            if normalized.contains(alias) {
                return aliasLookup[alias]
            }
        }
        return nil
    }

    /// Maps an alias back to the canonical brand when available.
    func canonicalName(for alias: String) -> String? {
        aliasLookup[alias.uppercased()]
    }

    private static func buildCatalog() -> [TireBrandEntry] {
        let entry: (String, [TireBrandCategory], TireBrandSource, [String]) -> TireBrandEntry = {
            let name = $0.uppercased()
            return TireBrandEntry(
                name: name,
                categories: Set($1),
                aliases: normalizedAliases(for: name, extras: $3),
                source: $2
            )
        }

        return [
            entry("MICHELIN", [.passenger, .suv, .truck, .motorcycle, .agriculture, .industrial, .ot], .association, ["MICH"]),
            entry("BRIDGESTONE", [.passenger, .suv, .truck, .motorcycle, .industrial], .association, ["BRIDGE", "B-RIDGE"]),
            entry("PIRELLI", [.passenger, .suv, .truck, .motorcycle], .association, ["P ZERO", "PZERO"]),
            entry("CONTINENTAL", [.passenger, .suv, .truck, .motorcycle], .association, ["CONT"]),
            entry("GOODYEAR", [.passenger, .suv, .truck, .industrial], .association, ["GOOD"]),
            entry("DUNLOP", [.passenger, .suv, .motorcycle], .association, ["DUN"]),
            entry("YOKOHAMA", [.passenger, .truck, .suv], .association, ["YOKO"]),
            entry("HANKOOK", [.passenger, .suv, .truck], .association, ["HANK"]),
            entry("KUMHO", [.passenger, .suv, .truck], .association, ["KUM"]),
            entry("TOYO", [.passenger, .suv, .truck], .association, ["TOY"]),
            entry("NOKIAN", [.passenger, .suv, .truck], .association, ["NOK"]),
            entry("FALKEN", [.passenger, .suv, .truck], .association, ["FAL"]),
            entry("COOPER", [.passenger, .suv, .truck], .association, ["COO"]),
            entry("MAXXIS", [.passenger, .suv, .truck, .motorcycle], .association, ["MAX"]),
            entry("NEXEN", [.passenger, .suv, .truck], .association, ["NEX"]),
            entry("BF GOODRICH", [.passenger, .suv, .truck], .association, ["BFG"]),
            entry("FIRESTONE", [.passenger, .suv, .truck], .association, ["FIRE"]),
            entry("GENERAL", [.passenger, .suv, .truck], .association, ["GEN"]),
            entry("UNIROYAL", [.passenger, .suv], .association, ["UNIR"]),
            entry("AVON", [.motorcycle], .association, ["AVN"]),
            entry("METZELER", [.motorcycle], .association, ["MET"]),
            entry("SUMITOMO", [.passenger, .truck], .association, ["SUM"]),
            entry("NITTO", [.passenger, .suv], .association, ["NIT"]),
            entry("KLEBER", [.passenger, .truck], .association, ["KLB"]),
            entry("VREDESTEIN", [.passenger, .suv], .association, ["VRED"]),
            entry("BKT", [.agriculture, .industrial, .ot], .commercial, ["BALKRISHNA"]),
            entry("CAMSO", [.agriculture, .industrial, .ot], .commercial, ["CAM"]),
            entry("ALLIANCE", [.agriculture, .truck, .ot], .commercial, []),
            entry("ROADSTONE", [.passenger, .suv, .truck], .commercial, ["ROAD"]),
            entry("CEAT", [.passenger, .truck], .commercial, []),
            entry("GITI", [.passenger, .suv, .truck], .commercial, []),
            entry("SAVA", [.passenger, .truck], .commercial, []),
            entry("MRF", [.passenger, .truck], .commercial, []),
            entry("LINGLONG", [.passenger, .suv, .truck], .commercial, []),
            entry("HIFLY", [.passenger], .community, []),
            entry("GOODRIDE", [.passenger, .suv], .community, []),
            entry("TRIANGLE", [.passenger, .truck], .community, []),
            entry("STARMAXX", [.passenger], .community, []),
            entry("MARANGONI", [.retread], .commercial, []),
            entry("ACCELERA", [.passenger, .suv], .commercial, []),
            entry("ZEXEN", [.passenger, .truck], .commercial, []),
            entry("WESTLAKE", [.passenger, .truck, .suv], .community, [])
        ]
    }

    private static func normalizedAliases(for brand: String, extras: [String]) -> [String] {
        var normalized = Set<String>()
        let base = brand.uppercased()
        normalized.insert(base)
        normalized.insert(base.replacingOccurrences(of: " ", with: ""))
        normalized.insert(base.replacingOccurrences(of: "-", with: ""))
        normalized.insert(base.replacingOccurrences(of: "'", with: ""))
        normalized.insert(base.replacingOccurrences(of: "/", with: ""))
        extras.forEach { normalized.insert($0.uppercased()) }
        return Array(normalized)
    }

    private static func buildAliasLookup(from entries: [TireBrandEntry]) -> [String: String] {
        var lookup = [String: String]()
        for entry in entries {
            lookup[entry.name] = entry.name
            entry.aliases.forEach { lookup[$0] = entry.name }
        }
        return lookup
    }

    private static func buildPrioritizedAliases(from lookup: [String: String]) -> [String] {
        lookup.keys.sorted { $0.count > $1.count }
    }
}
