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
        let performToggle = {
            self.isEnabled.toggle()
        }
        if Thread.isMainThread {
            performToggle()
        } else {
            DispatchQueue.main.async(execute: performToggle)
        }
    }
    
    public func logSimulation(action: String, target: String) {
        let entry = "[DRY-RUN SIMULATION] \(action): \(target)"
        print(entry)
        let appendEntry = {
            self.simulatedActionsLog.append(entry)
            if self.simulatedActionsLog.count > 100 {
                self.simulatedActionsLog.removeFirst(self.simulatedActionsLog.count - 100)
            }
        }
        if Thread.isMainThread {
            appendEntry()
        } else {
            DispatchQueue.main.async(execute: appendEntry)
        }
    }
    
    public func clearLog() {
        let clear = {
            self.simulatedActionsLog.removeAll()
        }
        if Thread.isMainThread {
            clear()
        } else {
            DispatchQueue.main.async(execute: clear)
        }
    }
}
