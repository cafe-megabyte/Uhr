import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static var shared: AppDelegate?
    
    override init() {
        super.init()
        AppDelegate.shared = self
    }
    
    func startWindowDragging() {
        if let window = NSApp.windows.first {
            window.performDrag(with: NSApp.currentEvent!)
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApp.windows.first {
            window.delegate = self
            window.minSize = NSSize(width: 300, height: 300)
            window.styleMask.insert(.resizable)
            
            // Setze initial den korrekten Hintergrund
            updateBackgroundColor(for: window)
            
            // Beobachter für Vollbildmodus-Änderungen hinzufügen
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidEnterFullScreen),
                name: NSWindow.didEnterFullScreenNotification,
                object: window
            )
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidExitFullScreen),
                name: NSWindow.didExitFullScreenNotification,
                object: window
            )
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidChangeScreen),
                name: NSWindow.didChangeScreenNotification,
                object: window
            )
        }
    }
    
    private func updateBackgroundColor(for window: NSWindow) {
        if window.styleMask.contains(.fullScreen) {
            window.backgroundColor = .black
        } else {
            window.backgroundColor = .windowBackgroundColor
        }
    }
    
    @objc func windowDidEnterFullScreen(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            window.backgroundColor = .black
        }
    }
    
    @objc func windowDidExitFullScreen(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            window.backgroundColor = .windowBackgroundColor
        }
    }
    
    @objc func windowDidChangeScreen(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            updateBackgroundColor(for: window)
        }
    }
    
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        // Hole die Größe des Hauptbildschirms
        guard let screen = sender.screen ?? NSScreen.main else {
            return frameSize
        }
        
        // Bestimme die größere Seite für das quadratische Fenster
        let maxDimension = max(frameSize.width, frameSize.height)
        
        // Berechne die maximale erlaubte Größe (kleinere Dimension des Bildschirms)
        let maxAllowedSize = min(
            screen.visibleFrame.width,
            screen.visibleFrame.height
        )
        
        // Stelle sicher, dass die Größe zwischen 300 und der maximalen Bildschirmgröße liegt
        let size = min(max(maxDimension, 300), maxAllowedSize)
        
        // Verwende die gleiche Größe für Breite und Höhe (quadratisch)
        return NSSize(width: size, height: size)
    }
}

@main
struct UhrApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 600, height: 600)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        .handlesExternalEvents(matching: Set(arrayLiteral: "*"))
    }
}

