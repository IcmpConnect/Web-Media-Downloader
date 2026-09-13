import SwiftUI
import AppKit

@main
struct WebMediaDownloaderApp: App {
    @ObservedObject private var langManager = LocalizationManager.shared

    init() {
        // Force activation policy to regular so it shows up in dock and menu bar when run via CLI/SPM
        NSApplication.shared.setActivationPolicy(.regular)
        
        // Set app icon programmatically at startup
        #if SWIFT_PACKAGE
        if let imagePath = Bundle.module.path(forResource: "app_icon", ofType: "png"),
           let image = NSImage(contentsOfFile: imagePath) {
            NSApplication.shared.applicationIconImage = image
        }
        #else
        if let image = NSImage(named: "AppIcon") {
            NSApplication.shared.applicationIconImage = image
        }
        #endif
    }

    var body: some Scene {
        WindowGroup("WebMediaDownloader") {
            ContentView()
                .frame(minWidth: 850, minHeight: 650)
                .onAppear {
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .help) {
                Button(loc("WebMediaDownloader Hilfe", "WebMediaDownloader Help")) {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenHelpRequested"), object: nil)
                }
                .keyboardShortcut("?", modifiers: .command)
            }
            CommandMenu(loc("Sprache", "Language")) {
                Button("🇩🇪 Deutsch") {
                    langManager.setLanguage(.de)
                }
                .keyboardShortcut("1", modifiers: [.command, .option])
                
                Button("🇬🇧 English") {
                    langManager.setLanguage(.en)
                }
                .keyboardShortcut("2", modifiers: [.command, .option])
                
                Divider()
                
                Button(loc("Sprache umschalten", "Toggle Language")) {
                    langManager.toggleLanguage()
                }
                .keyboardShortcut("L", modifiers: [.command, .shift])
            }
        }
    }
}
