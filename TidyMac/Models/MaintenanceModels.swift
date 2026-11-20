import Foundation
import SwiftUI

public enum TaskStatus: Equatable {
    case idle
    case running
    case success(message: String)
    case failed(error: String)
    case cancelled
}

public struct MaintenanceTask: Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let purpose: String
    public let whenToUse: String
    public let terminalCommand: String
    public let requiresAdmin: Bool
    public let icon: String
    public let tintColor: Color
    
    public var status: TaskStatus = .idle
    public var outputLog: String = ""
    public var lastRun: Date? = nil
    
    public init(
        id: String,
        title: String,
        subtitle: String,
        purpose: String,
        whenToUse: String,
        terminalCommand: String,
        requiresAdmin: Bool,
        icon: String,
        tintColor: Color = .pink
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.purpose = purpose
        self.whenToUse = whenToUse
        self.terminalCommand = terminalCommand
        self.requiresAdmin = requiresAdmin
        self.icon = icon
        self.tintColor = tintColor
    }
}
