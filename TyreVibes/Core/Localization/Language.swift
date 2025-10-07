import Foundation

enum Language: String, CaseIterable, Identifiable {
    case english = "en"
    case italian = "it"

    static let storageKey = "settings_selected_language"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .english:
            return "English (US)"
        case .italian:
            return "Italiano"
        }
    }

    var flag: String {
        switch self {
        case .english:
            return "🇺🇸"
        case .italian:
            return "🇮🇹"
        }
    }

    var appleLanguageCode: String {
        switch self {
        case .english:
            return "en"
        case .italian:
            return "it"
        }
    }

    static func resolve(from storedValue: String?) -> Language {
        guard let storedValue, let language = Language(rawValue: storedValue) else {
            return .english
        }
        return language
    }
}
