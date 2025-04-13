import SwiftUI
import WebKit

class ViewSizeObserver: ObservableObject {
    @Published var size: CGSize = .zero
}

struct ContentView: View {
    @StateObject private var sizeObserver = ViewSizeObserver()
    
    var body: some View {
        ZStack {
            WebViewContainer(sizeObserver: sizeObserver)
            Color.clear
                .contentShape(Rectangle())
                .allowsHitTesting(true)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            AppDelegate.shared?.startWindowDragging()
                        }
                )
        }
            .frame(minWidth: 300, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: SizePreferenceKey.self, value: geometry.size)
                        .onPreferenceChange(SizePreferenceKey.self) { newSize in
                            sizeObserver.size = newSize
                        }
                }
            )
    }
}

struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct WebViewContainer: NSViewRepresentable {
    @ObservedObject var sizeObserver: ViewSizeObserver
    
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        
        loadContent(in: webView)
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Lade den Inhalt neu, wenn sich die Größe ändert
        if context.coordinator.lastSize != sizeObserver.size {
            context.coordinator.lastSize = sizeObserver.size
            loadContent(in: nsView)
        }
    }
    
    private func loadContent(in webView: WKWebView) {
        if let htmlPath = Bundle.main.path(forResource: "index", ofType: "html") {
            if let htmlString = try? String(contentsOfFile: htmlPath, encoding: .utf8) {
                let baseURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources")
                
                if let jsPath = Bundle.main.path(forResource: "sbbUhr-1.3", ofType: "js"),
                   let jsContent = try? String(contentsOfFile: jsPath, encoding: .utf8) {
                    
                    let modifiedHtml = htmlString.replacingOccurrences(
                        of: "<script src=\"sbbUhr-1.3.js\"></script>",
                        with: "<script>\(jsContent)</script>"
                    )
                    
                    webView.loadHTMLString(modifiedHtml, baseURL: baseURL)
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewContainer
        var lastSize: CGSize = .zero
        
        init(_ parent: WebViewContainer) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("WebView finished loading")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView failed to load: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("WebView failed provisional navigation: \(error.localizedDescription)")
        }
    }
} 
