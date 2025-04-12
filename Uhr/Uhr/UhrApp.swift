import SwiftUI

@main
struct UhrApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 600, height: 600)
    }
} 