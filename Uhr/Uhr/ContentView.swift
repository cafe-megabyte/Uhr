import SwiftUI
import WebKit

struct ContentView: View {
    var body: some View {
        WebViewContainer()
            .frame(width: 600, height: 600)
    }
}

struct WebViewContainer: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        //configuration.preferences.javaScriptEnabled = true      "Decpricated
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        
        // Debug-Ausgaben
        print("Bundle path: \(Bundle.main.bundlePath)")
        
        if let htmlPath = Bundle.main.path(forResource: "index", ofType: "html") {
            print("HTML path found: \(htmlPath)")
            
            if let htmlString = try? String(contentsOfFile: htmlPath, encoding: .utf8) {
                print("HTML content loaded successfully")
                
                // Erstelle die baseURL für die Resources
                let baseURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources")
                print("Base URL: \(baseURL)")
                
                // Überprüfe, ob die JavaScript-Datei existiert
                if let jsPath = Bundle.main.path(forResource: "sbbUhr-1.3", ofType: "js") {
                    print("JavaScript path: \(jsPath)")
                    print("JavaScript file exists")
                    
                    // Lade die JavaScript-Datei
                    if let jsContent = try? String(contentsOfFile: jsPath, encoding: .utf8) {
                        print("JavaScript content loaded successfully")
                        
                        // Füge die JavaScript-Datei direkt in den HTML-String ein
                        let modifiedHtml = htmlString.replacingOccurrences(
                            of: "<script src=\"sbbUhr-1.3.js\"></script>",
                            with: "<script>\(jsContent)</script>"
                        )
                        
                        webView.loadHTMLString(modifiedHtml, baseURL: baseURL)
                    } else {
                        print("Failed to load JavaScript content")
                    }
                } else {
                    print("JavaScript file not found in bundle")
                }
                
                // Navigation Delegate für Debug-Informationen
                webView.navigationDelegate = context.coordinator
            } else {
                print("Failed to load HTML content")
            }
        } else {
            print("HTML file not found in bundle")
        }
        
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewContainer
        
        init(_ parent: WebViewContainer) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("WebView finished loading")
            // Überprüfe JavaScript-Fehler
            webView.evaluateJavaScript("console.log('JavaScript is running')") { (result, error) in
                if let error = error {
                    print("JavaScript error: \(error.localizedDescription)")
                } else {
                    print("JavaScript is running successfully")
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView failed to load: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("WebView failed provisional navigation: \(error.localizedDescription)")
        }
    }
} 
