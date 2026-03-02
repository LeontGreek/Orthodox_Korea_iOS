//
//  WebView.swift
//  Orthodox Korea
//
//  Created by LeontG Music on 11/8/25.
//

import SwiftUI
import WebKit
import Combine

// MARK: - Controller that owns ONE WKWebView and exposes controls
final class WebController: NSObject, ObservableObject {
    // Expose these for enabling/disabling buttons
    @Published private(set) var canGoBack: Bool = false
    @Published private(set) var canGoForward: Bool = false
    @Published private(set) var pageTitle: String?

    let webView: WKWebView
    private let startURL: URL

    init(
        startURL: URL,
        useEphemeralStore: Bool = false,   // true = no persistent cache/cookies
        forceMobileOnPad: Bool = false     // set true if you want iPad to request mobile sites
    ) {
        self.startURL = startURL

        let config = WKWebViewConfiguration()

        // Choose data store (persistent vs ephemeral)
        config.websiteDataStore = useEphemeralStore ? .nonPersistent() : .default()

        // Prefer desktop or mobile rendering
        let prefs = WKWebpagePreferences()
        if UIDevice.current.userInterfaceIdiom == .pad {
            prefs.preferredContentMode = forceMobileOnPad ? .mobile : .desktop
        } else {
            prefs.preferredContentMode = .mobile
        }
        config.defaultWebpagePreferences = prefs

        // Init webView
        self.webView = WKWebView(frame: .zero, configuration: config)

        super.init()

        // Basic behaviors
        self.webView.navigationDelegate = self
        self.webView.allowsBackForwardNavigationGestures = true
        self.webView.scrollView.alwaysBounceVertical = true

        // Initial load (clear if persistent store)
        goHome(clearBefore: !useEphemeralStore)
    }

    // MARK: - Public controls
    func load(_ url: URL, cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy) {
        let req = URLRequest(url: url, cachePolicy: cachePolicy, timeoutInterval: 60)
        webView.load(req)
    }

    func goBack() {
        if webView.canGoBack { webView.goBack() }
    }

    func goForward() {
        if webView.canGoForward { webView.goForward() }
    }

    func reload() {
        webView.reload()
    }

    func hardReload() {
        if let url = webView.url {
            let req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60)
            webView.load(req)
        } else {
            webView.reload()
        }
    }

    func goHome(clearBefore: Bool = true) {
        let performLoad = { [weak self] in
            guard let self else { return }
            self.load(self.startURL, cachePolicy: .reloadIgnoringLocalCacheData)
        }

        if clearBefore {
            clearWebsiteData(completion: performLoad)
        } else {
            performLoad()
        }
    }
    
    func changeLanguage(lang: String) {
        let performLoad = { [weak self] in
            guard let self else { return }
            if lang == "el" {
                if let url = URL(string: "https://orthodoxkorea.org/el") {
                    self.load(url, cachePolicy: .reloadIgnoringLocalCacheData)
                }
            } else if lang == "ru" {
                if let url = URL(string: "https://orthodoxkorea.org/ru") {
                    self.load(url, cachePolicy: .reloadIgnoringLocalCacheData)
                }
            } else if lang == "uk" {
                if let url = URL(string: "https://orthodoxkorea.org/uk") {
                    self.load(url, cachePolicy: .reloadIgnoringLocalCacheData)
                }
            } else if lang == "ko" {
                if let url = URL(string: "https://orthodoxkorea.org/ko") {
                    self.load(url, cachePolicy: .reloadIgnoringLocalCacheData)
                }
            } else if lang == "en" {
                if let url = URL(string: "https://orthodoxkorea.org/en") {
                    self.load(url, cachePolicy: .reloadIgnoringLocalCacheData)
                }
            } else {
                self.load(self.startURL, cachePolicy: .reloadIgnoringLocalCacheData)
            }
        }
        performLoad()
    }

    // MARK: - Data clearing
    /// Clears cache, cookies, local storage, etc. Calls completion on main after done.
    func clearWebsiteData(completion: (() -> Void)? = nil) {
        let store = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()

        store.removeData(ofTypes: types, modifiedSince: Date(timeIntervalSince1970: 0)) { [weak self] in
            // Clear URLCache & HTTPCookieStorage as well (belt-and-suspenders)
            URLCache.shared.removeAllCachedResponses()
            HTTPCookieStorage.shared.cookies?.forEach { HTTPCookieStorage.shared.deleteCookie($0) }

            // Minor delay ensures the store settles before next load
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                completion?()
                // Refresh button states after clear
                if let wv = self?.webView {
                    self?.syncNavState(with: wv)
                }
            }
        }
    }

    // MARK: - Helpers
    private func syncNavState(with webView: WKWebView) {
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        pageTitle = webView.title
    }
}

// MARK: - WKNavigationDelegate
extension WebController: WKNavigationDelegate {
    // Capture target="_blank" etc. and open inside same webView
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        syncNavState(with: webView)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        syncNavState(with: webView)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        // If the process is killed, try to reload gracefully
        webView.reload()
    }
}

// MARK: - Light-weight wrapper for SwiftUI
struct WebContainerView: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Intentionally empty: we do NOT auto-reload on SwiftUI updates.
    }
}

