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

public final class DeletionLogManager: ObservableObject, @unchecked Sendable {
    public static let shared = DeletionLogManager()
    
    @Published public private(set) var records: [DeletionRecord] = []
    
    private let logFileURL: URL
    private let queue = DispatchQueue(label: "com.tidymac.deletionlog", qos: .utility)
    
    private convenience init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let tidyMacDir = appSupport.appendingPathComponent("TidyMac", isDirectory: true)
        self.init(storageDirectory: tidyMacDir)
    }
    
    public convenience init(storageDirectory: URL) {
        try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        self.init(logFileURL: storageDirectory.appendingPathComponent("deletion_history.json"))
    }
    
    public init(logFileURL: URL) {
        self.logFileURL = logFileURL
        try? FileManager.default.createDirectory(at: logFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
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
        
        let updateAndPersist = { [weak self] in
            guard let self = self else { return }
            self.records.insert(record, at: 0)
            
            // Keep maximum 500 recent records to prevent unbounded growth
            if self.records.count > 500 {
                self.records = Array(self.records.prefix(500))
            }
            
            let snapshot = self.records
            self.queue.async { [weak self] in
                self?.persistRecords(snapshot)
            }
            
            AppLogger.cleanup.info("Deletion logged: [\(sourceModule)] \(path) -> \(destination.rawValue) (Success: \(isSuccess))")
        }
        
        if Thread.isMainThread {
            updateAndPersist()
        } else {
            DispatchQueue.main.async(execute: updateAndPersist)
        }
    }
    
    private func loadRecords() {
        guard FileManager.default.fileExists(atPath: self.logFileURL.path),
              let data = try? Data(contentsOf: self.logFileURL),
              let loaded = try? JSONDecoder().decode([DeletionRecord].self, from: data) else {
            return
        }
        self.records = Array(loaded.prefix(500))
    }
    
    /// Waits for all queued disk persistence writes to complete.
    public func flush() {
        queue.sync {}
    }
    
    /// Waits for any main-queue record mutations and subsequent disk persistence writes to complete.
    public func flushAsync() async {
        let persistenceQueue = self.queue
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                persistenceQueue.async {
                    continuation.resume()
                }
            }
        }
    }
    
    private func persistRecords(_ snapshot: [DeletionRecord]) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: self.logFileURL, options: .atomic)
    }
    
    public func clearHistory() {
        let clearOnMain = { [weak self] in
            guard let self = self else { return }
            self.records.removeAll()
            self.queue.async { [weak self] in
                guard let self = self else { return }
                try? FileManager.default.removeItem(at: self.logFileURL)
                AppLogger.cleanup.info("Deletion history cleared by user.")
            }
        }
        
        if Thread.isMainThread {
            clearOnMain()
        } else {
            DispatchQueue.main.async(execute: clearOnMain)
        }
    }
}
