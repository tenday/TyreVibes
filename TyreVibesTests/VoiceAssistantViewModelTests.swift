import XCTest
@testable import TyreVibes

@MainActor
final class VoiceAssistantViewModelTests: XCTestCase {
    func testHandleManualInputUsesDeepSeekResponseOnSuccess() async {
        let deepSeek = MockDeepSeekService(
            isConfigured: true,
            result: .success("Risposta DeepSeek valida")
        )

        let viewModel = VoiceAssistantViewModel(
            deepSeekService: deepSeek,
            shouldSpeakResponses: false,
            refreshUserStatsHandler: {}
        )
        viewModel.contextProvider = { .empty }

        viewModel.handleManualInput("Spiegami la rotazione gomme")
        await waitUntil { viewModel.messages.count >= 2 }

        XCTAssertEqual(deepSeek.callCount, 1)
        XCTAssertEqual(viewModel.messages.last?.role, .assistant)
        XCTAssertEqual(viewModel.messages.last?.text, "Risposta DeepSeek valida")
    }

    func testHandleManualInputFallsBackWhenDeepSeekErrors() async {
        let deepSeek = MockDeepSeekService(
            isConfigured: true,
            result: .failure(DeepSeekServiceError.httpError(statusCode: 401, message: "Unauthorized"))
        )

        let viewModel = VoiceAssistantViewModel(
            deepSeekService: deepSeek,
            shouldSpeakResponses: false,
            refreshUserStatsHandler: {}
        )
        viewModel.contextProvider = { .empty }

        viewModel.handleManualInput("quanti veicoli posso aggiungere?")
        await waitUntil { viewModel.messages.count >= 2 }

        XCTAssertEqual(deepSeek.callCount, 1)
        XCTAssertEqual(viewModel.messages.last?.role, .assistant)
        XCTAssertEqual(
            viewModel.messages.last?.text,
            "Non riesco a recuperare i dati del garage in questo momento. Riprova tra poco."
        )
    }

    func testHandleManualInputFallsBackWhenDeepSeekResponseIsBanned() async {
        let deepSeek = MockDeepSeekService(
            isConfigured: true,
            result: .success("Puoi trovarlo su google: http://example.com")
        )

        let viewModel = VoiceAssistantViewModel(
            deepSeekService: deepSeek,
            shouldSpeakResponses: false,
            refreshUserStatsHandler: {}
        )
        viewModel.contextProvider = { .empty }

        viewModel.handleManualInput("quanti veicoli posso aggiungere?")
        await waitUntil { viewModel.messages.count >= 2 }

        XCTAssertEqual(deepSeek.callCount, 1)
        XCTAssertEqual(viewModel.messages.last?.role, .assistant)
        XCTAssertEqual(
            viewModel.messages.last?.text,
            "Non riesco a recuperare i dati del garage in questo momento. Riprova tra poco."
        )
        XCTAssertFalse(viewModel.messages.last?.text.lowercased().contains("google") ?? false)
    }

    private func waitUntil(
        timeout: TimeInterval = 2.0,
        condition: @escaping () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("Timeout waiting for async condition")
    }
}

private final class MockDeepSeekService: DeepSeekServiceProtocol {
    let isConfigured: Bool
    var result: Result<String, Error>
    private(set) var callCount = 0

    init(isConfigured: Bool, result: Result<String, Error>) {
        self.isConfigured = isConfigured
        self.result = result
    }

    func generateResponse(prompt: String) async throws -> String {
        callCount += 1
        return try result.get()
    }
}
