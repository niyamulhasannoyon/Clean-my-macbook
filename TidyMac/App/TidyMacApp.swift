import SwiftUI

@main
struct TidyMacApp: App {
    @StateObject private var storage = StorageModel.shared
    @StateObject private var fdaManager = FullDiskAccessManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(storage)
                .environmentObject(fdaManager)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 980, height: 650)
        
        // Menu Bar Extra (Status Bar Item with Storage Info)
        MenuBarExtra("TidyMac", systemImage: "sparkles") {
            MenuBarView()
                .environmentObject(storage)
                .environmentObject(fdaManager)
        }
        .menuBarExtraStyle(.window)
    }
}
