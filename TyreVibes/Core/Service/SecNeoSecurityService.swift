import CryptoKit
import Foundation

/// Lightweight client-side security headers for SecNeo-style backend verification.
/// Real Alibaba SDK attestation can be plugged in by replacing token/signature generation.
final class SecNeoSecurityService {
    static let shared = SecNeoSecurityService()

    private struct Configuration {
        let enabled: Bool
        let appKey: String?
        let staticToken: String?
        let sharedSecret: String?
    }

    private let configuration: Configuration

    private init() {
        let plistPath = Bundle.main.path(forResource: "Api", ofType: "plist")
        let plist = plistPath.flatMap { NSDictionary(contentsOfFile: $0) }

        let enabledValue = plist?["SECNEO_ENABLED"]
        let enabled = Self.bool(from: enabledValue)

        let appKey = (plist?["SECNEO_APP_KEY"] as? String)?.trimmedNilIfEmpty
        let staticToken = (plist?["SECNEO_TOKEN"] as? String)?.trimmedNilIfEmpty
        let sharedSecret = (plist?["SECNEO_SHARED_SECRET"] as? String)?.trimmedNilIfEmpty

        configuration = Configuration(
            enabled: enabled,
            appKey: appKey,
            staticToken: staticToken,
            sharedSecret: sharedSecret
        )

        #if DEBUG
        if enabled, appKey == nil {
            print("⚠️ [SecNeoSecurityService] SECNEO_ENABLED=true ma SECNEO_APP_KEY è mancante.")
        }
        #endif
    }

    var isEnabled: Bool {
        configuration.enabled && configuration.appKey != nil
    }

    func applySecurityHeaders(to request: inout URLRequest) {
        guard isEnabled, let appKey = configuration.appKey else { return }

        let timestamp = String(Int(Date().timeIntervalSince1970 * 1_000))
        let nonce = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let canonicalPath = request.url?.path ?? "/"
        let method = request.httpMethod ?? "GET"
        let signaturePayload = "\(method)|\(canonicalPath)|\(timestamp)|\(nonce)"

        request.setValue(appKey, forHTTPHeaderField: "X-SecNeo-App-Key")
        request.setValue(timestamp, forHTTPHeaderField: "X-SecNeo-Timestamp")
        request.setValue(nonce, forHTTPHeaderField: "X-SecNeo-Nonce")

        if let token = configuration.staticToken {
            request.setValue(token, forHTTPHeaderField: "X-SecNeo-Token")
        }

        if let secret = configuration.sharedSecret {
            let signature = Self.hmacSHA256Hex(payload: signaturePayload, secret: secret)
            request.setValue(signature, forHTTPHeaderField: "X-SecNeo-Signature")
        }
    }

    private static func bool(from value: Any?) -> Bool {
        if let boolValue = value as? Bool { return boolValue }
        if let stringValue = value as? String {
            return ["1", "true", "yes", "on"].contains(stringValue.lowercased())
        }
        return false
    }

    private static func hmacSHA256Hex(payload: String, secret: String) -> String {
        let key = SymmetricKey(data: Data(secret.utf8))
        let digest = HMAC<SHA256>.authenticationCode(for: Data(payload.utf8), using: key)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

private extension String {
    var trimmedNilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
