import SwiftUI
import Foundation

// MARK: - Keep One Auto-Select Strategies
public enum DuplicateKeepStrategy: String, CaseIterable, Identifiable {
    case keepOldest = "Keep Oldest Original"
    case keepNewest = "Keep Newest Copy"
    case keepShortestPath = "Keep Shortest Path"
    
    public var id: String { rawValue }
    
    public var description: String {
        switch self {
        case .keepOldest:
            return "Retains the earliest created or modified file, selecting all newer duplicates for removal."
        case .keepNewest:
            return "Retains the most recently modified file, selecting older copies for removal."
        case .keepShortestPath:
            return "Retains the file located in the most shallow / direct folder path."
        }
    }
}

// MARK: - Duplicate File Item
public struct DuplicateFileItem: Identifiable, Hashable {
    public let id: UUID
    public let url: URL
    public let path: String
    public let directoryPath: String
    public let name: String
    public let size: Int64
    public let modificationDate: Date
    public var isSelectedForRemoval: Bool
    public var isKeptOriginal: Bool
    
    public init(
        id: UUID = UUID(),
        url: URL,
        path: String,
        directoryPath: String,
        name: String,
        size: Int64,
        modificationDate: Date,
        isSelectedForRemoval: Bool = false,
        isKeptOriginal: Bool = false
    ) {
        self.id = id
        self.url = url
        self.path = path
        self.directoryPath = directoryPath
        self.name = name
        self.size = size
        self.modificationDate = modificationDate
        self.isSelectedForRemoval = isSelectedForRemoval
        self.isKeptOriginal = isKeptOriginal
    }
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: modificationDate)
    }
}

// MARK: - Duplicate Group
public struct DuplicateGroup: Identifiable {
    public let id: UUID
    public let fullHash: String
    public let fileSize: Int64
    public let fileName: String
    public let category: String
    public let icon: String
    public let color: Color
    public var files: [DuplicateFileItem]
    public var isExpanded: Bool
    
    public init(
        id: UUID = UUID(),
        fullHash: String,
        fileSize: Int64,
        fileName: String,
        category: String,
        icon: String,
        color: Color = .indigo,
        files: [DuplicateFileItem],
        isExpanded: Bool = false
    ) {
        self.id = id
        self.fullHash = fullHash
        self.fileSize = fileSize
        self.fileName = fileName
        self.category = category
        self.icon = icon
        self.color = color
        self.files = files
        self.isExpanded = isExpanded
    }
    
    public var fileCount: Int {
        files.count
    }
    
    public var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    /// Total space occupied by all copies
    public var totalSize: Int64 {
        Int64(files.count) * fileSize
    }
    
    /// Wasted duplicate space (all copies minus the 1 original that should be kept)
    public var wastedSpace: Int64 {
        Int64(max(0, files.count - 1)) * fileSize
    }
    
    public var formattedWastedSpace: String {
        ByteCountFormatter.string(fromByteCount: wastedSpace, countStyle: .file)
    }
    
    public var selectedCount: Int {
        files.filter { $0.isSelectedForRemoval }.count
    }
    
    public var selectedWastedSpace: Int64 {
        Int64(selectedCount) * fileSize
    }
    
    public var formattedSelectedWastedSpace: String {
        ByteCountFormatter.string(fromByteCount: selectedWastedSpace, countStyle: .file)
    }
    
    public var allCopiesSelected: Bool {
        !files.isEmpty && files.allSatisfy { $0.isSelectedForRemoval }
    }
}
