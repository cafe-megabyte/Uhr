import SwiftUI

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
            window.tabbingMode = .disallowed
            
            // Fenster transparent machen
            window.isOpaque = false
            window.hasShadow = false
            window.backgroundColor = .clear
            
            // Titlebar transparent aber funktional machen
            if let titlebarView = window.standardWindowButton(NSWindow.ButtonType.closeButton)?.superview?.superview {
                titlebarView.isHidden = false
                titlebarView.alphaValue = 0.0
            }
            
            // Standardfensterbuttons verstecken aber funktional lassen
            [NSWindow.ButtonType.closeButton, 
             NSWindow.ButtonType.miniaturizeButton, 
             NSWindow.ButtonType.zoomButton].forEach { buttonType in
                window.standardWindowButton(buttonType)?.isHidden = false
                window.standardWindowButton(buttonType)?.alphaValue = 0.0
            }
            
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
            window.isOpaque = true
        } else {
            window.backgroundColor = .clear
            window.isOpaque = false
        }
    }
    
    @objc func windowDidEnterFullScreen(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            window.backgroundColor = .black
        }
    }
    
    @objc func windowDidExitFullScreen(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            
            // Titlebar wieder unsichtbar machen
            if let titlebarView = window.standardWindowButton(NSWindow.ButtonType.closeButton)?.superview?.superview {
                titlebarView.alphaValue = 0.0
            }
            
            // Fenstersteuerelemente wieder unsichtbar machen
            [NSWindow.ButtonType.closeButton, 
             NSWindow.ButtonType.miniaturizeButton, 
             NSWindow.ButtonType.zoomButton].forEach { buttonType in
                window.standardWindowButton(buttonType)?.alphaValue = 0.0
            }
            
            // Fensterrahmen transparent machen
            window.contentView?.wantsLayer = true
            window.contentView?.layer?.cornerRadius = 0
            window.titlebarAppearsTransparent = true
            
            // Erzwinge Neuzeichnen durch minimale Größenänderung
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let currentFrame = window.frame
                var newFrame = currentFrame
                newFrame.size.width += 1
                window.setFrame(newFrame, display: true)
                newFrame.size.width -= 1
                window.setFrame(newFrame, display: true)
            }
        }
    }
    
    @objc func windowDidChangeScreen(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            updateBackgroundColor(for: window)
        }
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApplication.shared.terminate(self)
        return true
    }
    
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        // Hole die Größe des Hauptbildschirms
        guard let screen = sender.screen ?? NSScreen.main else {
            return frameSize
        }
        
        // Berechne die maximale erlaubte Größe (kleinere Dimension des Bildschirms)
        let maxAllowedSize = min(
            screen.visibleFrame.width,
            screen.visibleFrame.height
        )
        
        // Wenn die Breite sich mehr verändert hat als die Höhe, nutze die Breite als Basis
        // Ansonsten nutze die Höhe als Basis für die quadratische Form
        let size: CGFloat
        let currentSize = sender.frame.size
        let widthDiff = abs(frameSize.width - currentSize.width)
        let heightDiff = abs(frameSize.height - currentSize.height)
        
        if widthDiff > heightDiff {
            size = frameSize.width
        } else {
            size = frameSize.height
        }
        
        // Stelle sicher, dass die Größe zwischen 300 und der maximalen Bildschirmgröße liegt
        let clampedSize = min(max(size, 300), maxAllowedSize)
        
        // Verwende die gleiche Größe für Breite und Höhe (quadratisch)
        return NSSize(width: clampedSize, height: clampedSize)
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
        .defaultPosition(.center)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) { };
            CommandGroup(replacing: .pasteboard) { };
            CommandGroup(replacing: .undoRedo) { };
            CommandGroup(replacing: .systemServices) { }
        }
        .handlesExternalEvents(matching: Set(arrayLiteral: "*"))
    }
}

