import Foundation
import os

public enum DeletionDestination: String, Codable {
    case trash = "Trash"
    case permanent = "Permanent Deletion"
    case simulated = "Simulated (Dry-Run)"
}

public struct DeletionRecord: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let sourceModule: String
    public let path: String
    public let sizeBytes: Int64
    public let destination: DeletionDestination
    public let isSuccess: Bool
    public let errorMessage: String?
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        sourceModule: String,
        path: String,
        sizeBytes: Int64,
        destination: DeletionDestination,
        isSuccess: Bool,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sourceModule = sourceModule
        self.path = path
        self.sizeBytes = sizeBytes
        self.destination = destination
        self.isSuccess = isSuccess
        self.errorMessage = errorMessage
    }
}

public final class DeletionLogManager: ObservableObject {
    public static let shared = DeletionLogManager()
    
    @Published public private(set) var records: [DeletionRecord] = []
    
    private let logFileURL: URL
    private let queue = DispatchQueue(label: "com.tidymac.deletionlog", qos: .utility)
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let tidyMacDir = appSupport.appendingPathComponent("TidyMac", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: tidyMacDir, withIntermediateDirectories: true)
        self.logFileURL = tidyMacDir.appendingPathComponent("deletion_history.json")
        loadRecords()
    }
    
    public func log(
        sourceModule: String,
        path: String,
        sizeBytes: Int64,
        destination: DeletionDestination,
        isSuccess: Bool,
        errorMessage: String? = nil
    ) {
        let record = DeletionRecord(
            sourceModule: sourceModule,
            path: path,
            sizeBytes: sizeBytes,
            destination: destination,
            isSuccess: isSuccess,
            errorMessage: errorMessage
        )
        
        queue.async { [weak self] in
            guard let self = self else { return }
            self.records.insert(record, at: 0)
            
            // Keep maximum 500 recent records to prevent unbounded growth
            if self.records.count > 500 {
                self.records = Array(self.records.prefix(500))
            }
            
            self.persistRecords()
            
            AppLogger.cleanup.info("Deletion logged: [\(sourceModule)] \(path) -> \(destination.rawValue) (Success: \(isSuccess))")
        }
    }
    
    private func loadRecords() {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard FileManager.default.fileExists(atPath: self.logFileURL.path),
                  let data = try? Data(contentsOf: self.logFileURL),
                  let loaded = try? JSONDecoder().decode([DeletionRecord].self, from: data) else {
                return
            }
            DispatchQueue.main.async {
                self.records = loaded
            }
        }
    }
    
    private func persistRecords() {
        guard let data = try? JSONEncoder().encode(self.records) else { return }
        try? data.write(to: self.logFileURL, options: .atomic)
    }
    
    public func clearHistory() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.records.removeAll()
            try? FileManager.default.removeItem(at: self.logFileURL)
            AppLogger.cleanup.info("Deletion history cleared by user.")
        }
    }
}
