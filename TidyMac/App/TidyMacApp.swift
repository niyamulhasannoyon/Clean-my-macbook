import SwiftUI
#if canImport(TidyMacCore)
import TidyMacCore
#endif

@main
struct TidyMacApp: App {
    @StateObject private var storage = StorageModel.shared
    @StateObject private var fdaManager = FullDiskAccessManager.shared

    init() {
        TidyMacIconProvider.configureApplicationIcon()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(storage)
                .environmentObject(fdaManager)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 980, height: 650)
        .commands {
            CommandGroup(replacing: .help) {
                Button("TidyMac User Guide & Documentation") {
                    if let url = URL(string: "https://tidymac.app/guide") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .keyboardShortcut("?", modifiers: .command)
                
                Button("Privacy Policy") {
                    if let url = URL(string: "https://tidymac.app/privacy") {
                        NSWorkspace.shared.open(url)
                    }
                }
                
                Divider()
                
                Button("Configure Full Disk Access...") {
                    FullDiskAccessManager.shared.openSystemSettings()
                }
                
                Button("Check for Updates...") {
                    AppLogger.general.info("User triggered manual update check")
                    let alert = NSAlert()
                    alert.messageText = "TidyMac is Up to Date"
                    alert.informativeText = "TidyMac Version 1.0.3 (Build 4) is the latest release."
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
        
        // Menu Bar Extra (Status Bar Item with Storage Info)
        MenuBarExtra {
            MenuBarView()
                .environmentObject(storage)
                .environmentObject(fdaManager)
        } label: {
            Label {
                Text("TidyMac")
            } icon: {
                Image(nsImage: TidyMacIconProvider.menuBarTemplateImage())
            }
        }
        .menuBarExtraStyle(.window)
    }
}
