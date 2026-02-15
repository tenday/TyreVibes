import XCTest
@testable import TyreVibes

final class DeepSeekServiceTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testIsConfiguredFalseWhenApiKeyIsEmpty() {
        let service = DeepSeekService(
            session: makeSession(),
            baseURL: URL(string: "https://api.deepseek.com/chat/completions"),
            apiKey: "",
            model: "deepseek-chat"
        )

        XCTAssertFalse(service.isConfigured)
    }

    func testIsConfiguredTrueWhenApiKeyAndBaseURLArePresent() {
        let service = DeepSeekService(
            session: makeSession(),
            baseURL: URL(string: "https://api.deepseek.com/chat/completions"),
            apiKey: "test-key",
            model: "deepseek-chat"
        )

        XCTAssertTrue(service.isConfigured)
    }

    func testGenerateResponseParsesChoiceContent() async throws {
        let responseBody = """
        {
          "choices": [
            { "message": { "content": "Risposta DeepSeek" } }
          ]
        }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, responseBody)
        }

        let service = DeepSeekService(
            session: makeSession(),
            baseURL: URL(string: "https://api.deepseek.com/chat/completions"),
            apiKey: "test-key",
            model: "deepseek-chat"
        )

        let result = try await service.generateResponse(prompt: "Ciao")
        XCTAssertEqual(result, "Risposta DeepSeek")
    }

    func testGenerateResponseThrowsHttpErrorFor401429500() async {
        let statuses = [401, 429, 500]

        for status in statuses {
            MockURLProtocol.requestHandler = { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: status,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                let body = Data("{\"error\":\"status \(status)\"}".utf8)
                return (response, body)
            }

            let service = DeepSeekService(
                session: makeSession(),
                baseURL: URL(string: "https://api.deepseek.com/chat/completions"),
                apiKey: "test-key",
                model: "deepseek-chat"
            )

            do {
                _ = try await service.generateResponse(prompt: "Ciao")
                XCTFail("Expected httpError for status \(status)")
            } catch let error as DeepSeekServiceError {
                guard case .httpError(let statusCode, _) = error else {
                    XCTFail("Expected .httpError, got \(error)")
                    continue
                }
                XCTAssertEqual(statusCode, status)
            } catch {
                XCTFail("Unexpected error \(error)")
            }
        }
    }

    func testGenerateResponseThrowsDecodingErrorForMalformedPayload() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("not-json".utf8))
        }

        let service = DeepSeekService(
            session: makeSession(),
            baseURL: URL(string: "https://api.deepseek.com/chat/completions"),
            apiKey: "test-key",
            model: "deepseek-chat"
        )

        do {
            _ = try await service.generateResponse(prompt: "Ciao")
            XCTFail("Expected decoding error")
        } catch let error as DeepSeekServiceError {
            guard case .decodingError = error else {
                XCTFail("Expected .decodingError, got \(error)")
                return
            }
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "MockURLProtocol", code: -1))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
