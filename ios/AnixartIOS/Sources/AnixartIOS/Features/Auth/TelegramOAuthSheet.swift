import SwiftUI
import UIKit
import WebKit

struct TelegramOAuthSheet: View {
    let request: OAuthService.TelegramAuthRequest
    let onComplete: (Result<String, Error>) -> Void

    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                TelegramAuthWebView(
                    request: request,
                    isLoading: $isLoading,
                    onComplete: onComplete
                )
                if isLoading {
                    ProgressView("Загрузка Telegram OAuth...")
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .navigationTitle("Вход через Telegram")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        onComplete(.failure(OAuthError.cancelled))
                    }
                }
            }
        }
    }
}

private struct TelegramAuthWebView: UIViewRepresentable {
    let request: OAuthService.TelegramAuthRequest
    @Binding var isLoading: Bool
    let onComplete: (Result<String, Error>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            redirectHost: request.redirectHost,
            isLoading: $isLoading,
            onComplete: onComplete
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.load(URLRequest(url: request.authURL))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private let redirectHost: String
        private let isLoading: Binding<Bool>
        private let onComplete: (Result<String, Error>) -> Void
        private var didFinish = false

        init(
            redirectHost: String,
            isLoading: Binding<Bool>,
            onComplete: @escaping (Result<String, Error>) -> Void
        ) {
            self.redirectHost = redirectHost
            self.isLoading = isLoading
            self.onComplete = onComplete
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading.wrappedValue = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading.wrappedValue = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading.wrappedValue = false
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            if handleInterceptedURL(url) {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let url = navigationAction.request.url {
                if !handleInterceptedURL(url) {
                    webView.load(navigationAction.request)
                }
            }
            return nil
        }

        private func handleInterceptedURL(_ url: URL) -> Bool {
            if url.scheme?.lowercased() == "tg" {
                UIApplication.shared.open(url)
                return true
            }

            guard url.host?.lowercased() == redirectHost.lowercased() else {
                return false
            }

            guard !didFinish else { return true }
            didFinish = true

            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let queryItems = components?.queryItems ?? []

            if let errorMsg = queryItems.first(where: { $0.name == "error_description" })?.value
                ?? queryItems.first(where: { $0.name == "error" })?.value,
               !errorMsg.isEmpty {
                onComplete(.failure(OAuthError.tokenExchangeFailed(errorMsg)))
                return true
            }

            if let code = queryItems.first(where: { $0.name == "code" })?.value, !code.isEmpty {
                onComplete(.success(code))
            } else {
                onComplete(.failure(OAuthError.invalidCallback))
            }
            return true
        }
    }
}
