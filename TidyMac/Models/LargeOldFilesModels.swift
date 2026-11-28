import SwiftUI
import Foundation

// MARK: - File Types
public enum LargeOldFileType: String, CaseIterable, Identifiable {
    case video = "Videos"
    case archive = "Archives"
    case diskImage = "Disk Images"
    case document = "Documents"
    case audio = "Audio"
    case picture = "Images"
    case other = "Other"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .video: return "film"
        case .archive: return "doc.zipper"
        case .diskImage: return "opticaldisc"
        case .document: return "doc.text.fill"
        case .audio: return "waveform"
        case .picture: return "photo.fill"
        case .other: return "doc.fill"
        }
    }
    
    public var color: Color {
        switch self {
        case .video: return .purple
        case .archive: return .orange
        case .diskImage: return .teal
        case .document: return .blue
        case .audio: return .pink
        case .picture: return .green
        case .other: return .secondary
        }
    }
    
    public static func detect(from url: URL) -> LargeOldFileType {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "mp4", "mov", "mkv", "avi", "wmv", "flv", "webm", "m4v", "ts", "mpeg", "mpg":
            return .video
        case "zip", "tar", "gz", "tgz", "bz2", "7z", "rar", "xz", "zst":
            return .archive
        case "dmg", "iso", "img", "pkg", "vdi", "vmdk", "qcow2", "sparseimage":
            return .diskImage
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "key", "numbers", "pages", "txt", "rtf", "csv", "sqlite", "epub":
            return .document
        case "mp3", "wav", "flac", "aac", "m4a", "ogg", "aiff", "alac", "wma":
            return .audio
        case "png", "jpg", "jpeg", "heic", "heif", "gif", "tiff", "tif", "raw", "cr2", "nef", "arw", "dng", "psd", "bmp", "svg", "webp":
            return .picture
        default:
            return .other
        }
    }
}

// MARK: - Large / Old File Item
public struct LargeOldFileItem: Identifiable, Hashable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let path: String
    public let size: Int64
    public let modificationDate: Date
    public let fileType: LargeOldFileType
    public var isSelected: Bool
    
    public init(
        id: UUID = UUID(),
        url: URL,
        name: String,
        path: String,
        size: Int64,
        modificationDate: Date,
        fileType: LargeOldFileType,
        isSelected: Bool = false
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.path = path
        self.size = size
        self.modificationDate = modificationDate
        self.fileType = fileType
        self.isSelected = isSelected
    }
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    public var isLarge: Bool {
        size >= 100 * 1024 * 1024 // 100 MB+
    }
    
    public var ageInDays: Int {
        max(0, Calendar.current.dateComponents([.day], from: modificationDate, to: Date()).day ?? 0)
    }
    
    public var isOld: Bool {
        ageInDays >= 365 // 1 Year+
    }
    
    public var formattedDate: String {
        Self.dateFormatter.string(from: modificationDate)
    }
    
    public var formattedAge: String {
        let days = ageInDays
        if days < 30 {
            return "\(days) days ago"
        } else if days < 365 {
            let months = max(1, days / 30)
            return "\(months) \(months == 1 ? "month" : "months") ago"
        } else {
            let years = Double(days) / 365.0
            if years < 1.1 {
                return "1 year ago"
            } else {
                return String(format: "%.1f years ago", years)
            }
        }
    }
}

// MARK: - Sort Options
public enum LargeOldSortOption: String, CaseIterable, Identifiable {
    case sizeDescending = "Size: Largest First"
    case sizeAscending = "Size: Smallest First"
    case dateOldest = "Date: Oldest First"
    case dateNewest = "Date: Newest First"
    case nameAZ = "Name: A to Z"
    case nameZA = "Name: Z to A"
    
    public var id: String { rawValue }
}

// MARK: - Filter Presets
public enum LargeOldCriteriaFilter: String, CaseIterable, Identifiable {
    case all = "All Matches"
    case largeOnly = "100MB+ Only"
    case oldOnly = "1+ Year Old Only"
    
    public var id: String { rawValue }
}
