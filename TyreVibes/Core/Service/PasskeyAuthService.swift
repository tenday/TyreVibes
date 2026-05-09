import AuthenticationServices
import Foundation

enum PasskeyAuthError: LocalizedError {
    case configMissing
    case invalidResponse
    case serverError(String)
    case notAuthenticated
    case attestationMissing

    var errorDescription: String? {
        switch self {
        case .configMissing:
            return "Configurazione passkey mancante."
        case .invalidResponse:
            return "Risposta server non valida."
        case .serverError(let message):
            return message.isEmpty ? "Errore server passkey." : message
        case .notAuthenticated:
            return "Effettua il login prima di creare una passkey."
        case .attestationMissing:
            return "Dati di attestazione mancanti dal dispositivo."
        }
    }
}

final class PasskeyAuthService: NSObject {
    static let shared = PasskeyAuthService()

    private struct Config {
        let baseURL: URL
        let anonKey: String
    }

    private struct RegistrationOptionsRequest: Encodable {
        let userId: String
        let email: String
        let displayName: String
    }

    private struct RegistrationOptionsResponse: Decodable {
        let rpId: String
        let challenge: String
        let userId: String
        let userName: String
        let userDisplayName: String?
    }

    private struct RegistrationVerifyRequest: Encodable {
        let id: String
        let rawId: String
        let type: String
        let response: RegistrationResponsePayload
        let userId: String
    }

    private struct RegistrationResponsePayload: Encodable {
        let clientDataJSON: String
        let attestationObject: String
    }

    private struct AuthenticationOptionsRequest: Encodable {
        let email: String?
    }

    private struct AuthenticationOptionsResponse: Decodable {
        struct AllowCredential: Decodable {
            let id: String
        }

        let rpId: String
        let challenge: String
        let allowCredentials: [AllowCredential]?
    }

    private struct AuthenticationVerifyRequest: Encodable {
        let id: String
        let rawId: String
        let type: String
        let response: AuthenticationResponsePayload
        let userId: String?
    }

    private struct AuthenticationResponsePayload: Encodable {
        let clientDataJSON: String
        let authenticatorData: String
        let signature: String
        let userHandle: String?
    }

    private struct PasskeyVerifyResponse: Decodable {
        let accessToken: String?
        let refreshToken: String?
        let success: Bool?
        let message: String?
    }

    private let registerOptionsPath = "passkeys/register-options"
    private let registerVerifyPath = "passkeys/register-verify"
    private let authOptionsPath = "passkeys/authenticate-options"
    private let authVerifyPath = "passkeys/authenticate-verify"

    @MainActor
    func registerPasskey(presentationAnchor: ASPresentationAnchor) async throws {
        guard let session = try? await SupabaseManager.client.auth.session else {
            throw PasskeyAuthError.notAuthenticated
        }

        let userId = session.user.id.uuidString
        let email = session.user.email ?? ""
        let displayName = email.isEmpty ? userId : email

        let options: RegistrationOptionsResponse = try await post(
            path: registerOptionsPath,
            body: RegistrationOptionsRequest(userId: userId, email: email, displayName: displayName),
            accessToken: session.accessToken
        )

        guard let challenge = base64URLDecode(options.challenge),
              let userIdData = base64URLDecode(options.userId) else {
            throw PasskeyAuthError.invalidResponse
        }

        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: options.rpId)
        let request = provider.createCredentialRegistrationRequest(
            challenge: challenge,
            name: options.userName,
            userID: userIdData
        )
        request.displayName = options.userDisplayName ?? options.userName

        let authorization = try await performAuthorization(
            requests: [request],
            presentationAnchor: presentationAnchor
        )

        guard let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration else {
            throw PasskeyAuthError.invalidResponse
        }

        guard let attestationObject = credential.rawAttestationObject else {
            throw PasskeyAuthError.attestationMissing
        }

        let verifyRequest = RegistrationVerifyRequest(
            id: base64URLEncode(credential.credentialID),
            rawId: base64URLEncode(credential.credentialID),
            type: "public-key",
            response: RegistrationResponsePayload(
                clientDataJSON: base64URLEncode(credential.rawClientDataJSON),
                attestationObject: base64URLEncode(attestationObject)
            ),
            userId: userId
        )

        let verifyResponse: PasskeyVerifyResponse = try await post(
            path: registerVerifyPath,
            body: verifyRequest,
            accessToken: session.accessToken
        )

        if verifyResponse.success == false {
            throw PasskeyAuthError.serverError(verifyResponse.message ?? "")
        }
    }

    @MainActor
    func authenticate(presentationAnchor: ASPresentationAnchor, email: String? = nil) async throws {
        let options: AuthenticationOptionsResponse = try await post(
            path: authOptionsPath,
            body: AuthenticationOptionsRequest(email: email),
            accessToken: nil
        )

        guard let challenge = base64URLDecode(options.challenge) else {
            throw PasskeyAuthError.invalidResponse
        }

        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: options.rpId)
        let request = provider.createCredentialAssertionRequest(challenge: challenge)

        if let allowCredentials = options.allowCredentials {
            let descriptors = allowCredentials.compactMap { credential -> ASAuthorizationPlatformPublicKeyCredentialDescriptor? in
                guard let data = base64URLDecode(credential.id) else { return nil }
                return ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: data)
            }
            request.allowedCredentials = descriptors
        }

        let authorization = try await performAuthorization(
            requests: [request],
            presentationAnchor: presentationAnchor
        )

        guard let assertion = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion else {
            throw PasskeyAuthError.invalidResponse
        }

        let verifyRequest = AuthenticationVerifyRequest(
            id: base64URLEncode(assertion.credentialID),
            rawId: base64URLEncode(assertion.credentialID),
            type: "public-key",
            response: AuthenticationResponsePayload(
                clientDataJSON: base64URLEncode(assertion.rawClientDataJSON),
                authenticatorData: base64URLEncode(assertion.rawAuthenticatorData),
                signature: base64URLEncode(assertion.signature),
                userHandle: assertion.userID.map { base64URLEncode($0) }
            ),
            userId: assertion.userID.map { base64URLEncode($0) }
        )

        let verifyResponse: PasskeyVerifyResponse = try await post(
            path: authVerifyPath,
            body: verifyRequest,
            accessToken: nil
        )

        guard let accessToken = verifyResponse.accessToken,
              let refreshToken = verifyResponse.refreshToken else {
            throw PasskeyAuthError.invalidResponse
        }

        _ = try await SupabaseManager.client.auth.setSession(
            accessToken: accessToken,
            refreshToken: refreshToken
        )
    }

    @MainActor
    private func performAuthorization(
        requests: [ASAuthorizationRequest],
        presentationAnchor: ASPresentationAnchor
    ) async throws -> ASAuthorization {
        let controller = ASAuthorizationController(authorizationRequests: requests)
        let delegate = PasskeyAuthorizationDelegate()
        controller.delegate = delegate
        controller.presentationContextProvider = delegate
        delegate.presentationAnchor = presentationAnchor

        return try await withCheckedThrowingContinuation { continuation in
            delegate.continuation = continuation
            controller.performRequests()
        }
    }

    private func post<Response: Decodable, Body: Encodable>(
        path: String,
        body: Body?,
        accessToken: String?
    ) async throws -> Response {
        let config = try loadConfig()
        let url = config.baseURL
            .appendingPathComponent("functions/v1")
            .appendingPathComponent(path)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.tyreVibesShared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PasskeyAuthError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw PasskeyAuthError.serverError(message)
        }

        return try JSONDecoder().decode(Response.self, from: data)
    }

    private func loadConfig() throws -> Config {
        guard let path = Bundle.main.path(forResource: "Api", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let urlString = plist["SUPABASE_URL"] as? String,
              let key = plist["SUPABASE_KEY"] as? String,
              let url = URL(string: urlString) else {
            throw PasskeyAuthError.configMissing
        }
        return Config(baseURL: url, anonKey: key)
    }

    private func base64URLDecode(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let padding = 4 - (base64.count % 4)
        if padding < 4 {
            base64 += String(repeating: "=", count: padding)
        }

        return Data(base64Encoded: base64)
    }

    private func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

@MainActor
private final class PasskeyAuthorizationDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    var continuation: CheckedContinuation<ASAuthorization, Error>?
    var presentationAnchor: ASPresentationAnchor?

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        presentationAnchor ?? ASPresentationAnchor()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation?.resume(returning: authorization)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
    }
}
