//
//  KeychainHelper.swift
//  TyreVibes
//
//  Created by Matteo La Manna on 26/07/25.
//

import Foundation
import Security // Import necessario per il Keychain

// MARK: - Keychain Helper
// Classe di supporto per salvare e caricare dati in modo sicuro nel Keychain.
class KeychainHelper {
    
    static let service = "com.tyrevibes.loginservice" // Usa un identificatore unico per la tua app
    static let account = "userCredentials"

    static func save(email: String, password: String) throws {
        let credentials = ["email": email, "password": password]
        let data = try JSONEncoder().encode(credentials)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        
        // Rimuovi eventuali dati esistenti prima di salvare
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
        }
    }

    static func load() -> (email: String, password: String)? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            let credentials = try? JSONDecoder().decode([String: String].self, from: data)
            if let email = credentials?["email"], let password = credentials?["password"] {
                return (email, password)
            }
        }
        return nil
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
