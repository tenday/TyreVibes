import Foundation
import SwiftUI
import ObjectiveC.runtime

@MainActor
final class LanguageManager: ObservableObject {
    @Published private(set) var currentLanguage: Language
    @Published var locale: Locale

    static let shared = LanguageManager()

    private init() {
        let stored = UserDefaults.standard.string(forKey: Language.storageKey)
        let resolved = Language.resolve(from: stored)
        currentLanguage = resolved
        locale = Locale(identifier: resolved.appleLanguageCode)
        Bundle.setLanguage(resolved.appleLanguageCode)
    }

    func setLanguage(_ language: Language) {
        guard language != currentLanguage else { return }

        currentLanguage = language
        locale = Locale(identifier: language.appleLanguageCode)

        UserDefaults.standard.set(language.rawValue, forKey: Language.storageKey)
        UserDefaults.standard.set([language.appleLanguageCode], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()

        Bundle.setLanguage(language.appleLanguageCode)
    }
}

private var bundleKey: UInt8 = 0

private final class LocalizedBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let languageCode = objc_getAssociatedObject(self, &bundleKey) as? String,
           let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        }

        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    static func setLanguage(_ language: String) {
        let isLanguageSet = objc_getAssociatedObject(Bundle.main, &bundleKey) != nil

        if !isLanguageSet {
            object_setClass(Bundle.main, LocalizedBundle.self)
        }

        objc_setAssociatedObject(Bundle.main, &bundleKey, language, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
