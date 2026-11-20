import Foundation
import SwiftUI

/// Central manager for Dry-Run simulation mode across TidyMac.
/// When Dry-Run is enabled, scanning proceeds normally, but all file removals,
/// cache deletions, and maintenance commands are simulated without modifying disk.
public final class DryRunManager: ObservableObject {
    public static let shared = DryRunManager()
    
    private let userDefaultsKey = "TidyMac_isDryRunEnabled"
    
    @Published public var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: userDefaultsKey)
        }
    }
    
    @Published public var simulatedActionsLog: [String] = []
    @Published public var isShowingSettingsSheet: Bool = false
    
    private init() {
        // Defaults to false (normal operation)
        self.isEnabled = UserDefaults.standard.bool(forKey: userDefaultsKey)
    }
    
    public func toggle() {
        isEnabled.toggle()
    }
    
    public func logSimulation(action: String, target: String) {
        let entry = "[DRY-RUN SIMULATION] \(action): \(target)"
        print(entry)
        simulatedActionsLog.append(entry)
        if simulatedActionsLog.count > 100 {
            simulatedActionsLog.removeFirst()
        }
    }
    
    public func clearLog() {
        simulatedActionsLog.removeAll()
    }
}
