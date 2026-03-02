//
//  ContentView.swift
//  Orthodox Korea
//
//  Created by LeontG Music on 11/8/25.
//

import SwiftUI
import WebKit
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    // Keep ONE controller alive for the whole view
    @StateObject private var web = WebController(
        startURL: URL(string: "https://orthodoxkorea.org/")!,
        useEphemeralStore: false,   // set true if you never want persistent cache/cookies
        forceMobileOnPad: false     // set true if you prefer mobile view on iPad
    )
    
    @State private var showLanguageMenu = false
    @State private var isToolbarHidden: Bool = false

    var body: some View {
        ZStack {
            // The web content
            WebContainerView(webView: web.webView)
                .ignoresSafeArea()
            
            WebScrollObserverView(webView: web.webView, isToolbarHidden: $isToolbarHidden)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)

            // Floating bottom toolbar
            VStack {
                Spacer()
                HStack(spacing: 24) {
                    // Home (clears cache + loads start URL)
                    Button {
                        web.goHome(clearBefore: true)
                    } label: {
                        Image(systemName: "house.circle.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .shadow(radius: 3)
                            .accessibilityLabel("Home")
                    }

                    // Back
                    Button {
                        web.goBack()
                    } label: {
                        Image(systemName: "chevron.left.circle.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .shadow(radius: 3)
                            .accessibilityLabel("Back")
                    }
                    .disabled(!web.canGoBack)

                    // Reload
                    Button {
                        web.reload()
                    } label: {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .shadow(radius: 3)
                            .accessibilityLabel("Reload")
                    }

                    // Forward
                    Button {
                        web.goForward()
                    } label: {
                        Image(systemName: "chevron.right.circle.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .shadow(radius: 3)
                            .accessibilityLabel("Forward")
                    }
                    .disabled(!web.canGoForward)
                    
                    Button(action: {
                        showLanguageMenu = true
                    }) {
                        Image(systemName: "globe.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.blue)
                            .shadow(radius: 3)
                    }
                    .confirmationDialog("Select Language", isPresented: $showLanguageMenu) {
                            Button("English") {
                                web.changeLanguage(lang: "en")
                            }
                            Button("한국어") {
                                web.changeLanguage(lang: "ko")
                            }
                            Button("Ελληνικά") {
                                web.changeLanguage(lang: "el")
                            }
                            Button("Русский") {
                                web.changeLanguage(lang: "ru")
                            }
                            Button("Українська") {
                                web.changeLanguage(lang: "uk")
                            }
                            Button("Cancel", role: .cancel) {}
                        }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.bottom, 24)
                .padding(.horizontal, 16)
                .opacity(isToolbarHidden ? 0 : 1)
                .offset(y: isToolbarHidden ? 80 : 0)
                .animation(.easeInOut(duration: 0.25), value: isToolbarHidden)
            }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .background:
                // Clear on app going to background
                web.clearWebsiteData()
            default:
                break
            }
        }
    }
}

struct WebScrollObserverView: UIViewRepresentable {
    let webView: WKWebView
    @Binding var isToolbarHidden: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isToolbarHidden: $isToolbarHidden)
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView(frame: .zero)
        // Attach delegate and retain it via coordinator
        webView.scrollView.delegate = context.coordinator
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if webView.scrollView.delegate !== context.coordinator {
            webView.scrollView.delegate = context.coordinator
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        @Binding var isToolbarHidden: Bool
        private var lastOffsetY: CGFloat = 0
        private var initialized = false
        
        private var accumulatedDelta: CGFloat = 0
        private let hideThreshold: CGFloat = 200 // points to hide
        private let showThreshold: CGFloat = 200 // points to show (smaller to add hysteresis)
        
        private func isAtTopOrBottom(_ scrollView: UIScrollView) -> Bool {
            let top = scrollView.contentOffset.y <= -scrollView.adjustedContentInset.top + 0.5
            let bottomLimit = max(0, scrollView.contentSize.height + scrollView.adjustedContentInset.bottom - scrollView.bounds.height)
            let bottom = scrollView.contentOffset.y >= bottomLimit - 0.5
            return top || bottom
        }

        init(isToolbarHidden: Binding<Bool>) {
            self._isToolbarHidden = isToolbarHidden
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let y = scrollView.contentOffset.y
            if !initialized {
                lastOffsetY = y
                initialized = true
                return
            }
            let delta = y - lastOffsetY
            lastOffsetY = y
            
            if isAtTopOrBottom(scrollView) {
                // Reduce sensitivity at edges to avoid rubber-band flicker
                if abs(delta) < 3 { return }
            }

            // Accumulate movement to avoid flicker
            if abs(delta) <= 1 { return } // ignore tiny jitter
            accumulatedDelta += delta

            if !isToolbarHidden {
                // Currently visible; require enough downward movement to hide
                if accumulatedDelta > hideThreshold {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isToolbarHidden = true
                    }
                    accumulatedDelta = 0
                }
            } else {
                // Currently hidden; require enough upward movement to show
                if accumulatedDelta < -showThreshold {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isToolbarHidden = false
                    }
                    accumulatedDelta = 0
                }
            }

            // Decay the accumulator a bit to prevent slow drift
            if accumulatedDelta > 0 {
                accumulatedDelta = max(0, accumulatedDelta - 0.5)
            } else if accumulatedDelta < 0 {
                accumulatedDelta = min(0, accumulatedDelta + 0.5)
            }
        }
        
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            accumulatedDelta = 0
        }
    }
}

#Preview {
    ContentView()
}

