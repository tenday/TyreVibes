import Foundation
import WebKit
import UIKit

enum FacileWebLookupError: LocalizedError {
    case lookupAlreadyRunning
    case invalidPlate
    case renderContextUnavailable
    case invalidNavigation
    case timedOut

    var errorDescription: String? {
        switch self {
        case .lookupAlreadyRunning:
            return "Una ricerca veicolo è già in corso"
        case .invalidPlate:
            return "Formato targa non valido"
        case .renderContextUnavailable:
            return "Contesto WebKit non disponibile"
        case .invalidNavigation:
            return "Navigazione della ricerca veicolo non valida"
        case .timedOut:
            return "Timeout durante la ricerca veicolo"
        }
    }
}

@MainActor
final class FacileWebLookupService: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    static let shared = FacileWebLookupService()

    private var webView: WKWebView?
    private var continuation: CheckedContinuation<FacileVehicleData, Error>?
    private var timeoutTask: Task<Void, Never>?

    func fetch(plate rawPlate: String) async throws -> FacileVehicleData {
        guard continuation == nil else {
            throw FacileWebLookupError.lookupAlreadyRunning
        }

        let plate = rawPlate.uppercased().filter { $0.isLetter || $0.isNumber }
        guard (5...8).contains(plate.count) else {
            throw FacileWebLookupError.invalidPlate
        }

        let script = try FacileWebFlow.interceptionScript(plate: plate)
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let controller = WKUserContentController()
            controller.addUserScript(WKUserScript(
                source: script,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            ))
            controller.add(self, name: FacileWebFlow.messageHandlerName)

            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = .nonPersistent()
            configuration.defaultWebpagePreferences.allowsContentJavaScript = true
            configuration.userContentController = controller

            let webView = WKWebView(
                frame: CGRect(x: -2, y: -2, width: 1, height: 1),
                configuration: configuration
            )
            webView.navigationDelegate = self
            webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
            webView.alpha = 0.01
            webView.isOpaque = false
            webView.isUserInteractionEnabled = false
            webView.accessibilityElementsHidden = true

            guard attachToRenderHierarchy(webView) else {
                finish(.failure(FacileWebLookupError.renderContextUnavailable))
                return
            }
            self.webView = webView

            timeoutTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 22_000_000_000)
                guard !Task.isCancelled else { return }
                self?.finish(.failure(FacileWebLookupError.timedOut))
            }

            var request = URLRequest(url: FacileWebFlow.lookupURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 18
            webView.load(request)
        }
    }

    func cancel() {
        finish(.failure(CancellationError()))
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == FacileWebFlow.messageHandlerName else { return }
        do {
            let data: Data
            if let string = message.body as? String {
                data = Data(string.utf8)
            } else {
                data = try JSONSerialization.data(withJSONObject: message.body)
            }
            finish(.success(try FacileVehicleResponseParser.parse(data: data)))
        } catch {
            finish(.failure(error))
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard
            navigationAction.targetFrame?.isMainFrame == true,
            let host = navigationAction.request.url?.host
        else {
            decisionHandler(.allow)
            return
        }
        let allowed = host == "facile.it" || host.hasSuffix(".facile.it")
        decisionHandler(allowed ? .allow : .cancel)
        if !allowed {
            finish(.failure(FacileWebLookupError.invalidNavigation))
        }
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        finish(.failure(error))
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        finish(.failure(error))
    }

    private func attachToRenderHierarchy(_ webView: WKWebView) -> Bool {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes
            .first(where: { $0.activationState == .foregroundActive })?
            .windows
            .first(where: { $0.isKeyWindow })
            ?? scenes.flatMap(\.windows).first(where: { !$0.isHidden })
        guard let container = window?.rootViewController?.view else { return false }
        container.addSubview(webView)
        return true
    }

    private func finish(_ result: Result<FacileVehicleData, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView?.configuration.userContentController.removeScriptMessageHandler(
            forName: FacileWebFlow.messageHandlerName
        )
        webView?.removeFromSuperview()
        webView = nil
        continuation.resume(with: result)
    }
}
