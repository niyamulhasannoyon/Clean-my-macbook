import Foundation
import SwiftUI
import AppKit

@MainActor
public final class DiskSpaceScanner: ObservableObject {
    public static let shared = DiskSpaceScanner()
    
    @Published public var rootNode: DiskNode?
    @Published public var currentNode: DiskNode?
    @Published public var breadcrumbs: [DiskNode] = []
    
    @Published public var isScanning: Bool = false
    @Published public var scanProgress: Double = 0.0
    @Published public var currentScanningPath: String = ""
    @Published public var statusMessage: String = "Ready to analyze disk space"
    
    @Published public var chartStyle: DiskChartStyle = .treemap
    @Published public var hoveredNode: DiskNode?
    @Published public var selectedNode: DiskNode?
    @Published public var scanError: String? = nil
    
    public init() {
        // Initial setup with Home folder
        let home = FileManager.default.homeDirectoryForCurrentUser
        let initialRoot = DiskNode(
            url: home,
            name: "Home (~)",
            path: home.path,
            isDirectory: true
        )
        self.rootNode = initialRoot
        self.currentNode = initialRoot
        self.breadcrumbs = [initialRoot]
    }
    
    // MARK: - Navigation: Drill Down
    public func drillDown(to node: DiskNode) {
        guard node.isDirectory && !node.children.isEmpty else {
            selectedNode = node
            return
        }
        
        selectedNode = nil
        hoveredNode = nil
        currentNode = node
        
        // Update breadcrumbs
        if let idx = breadcrumbs.firstIndex(where: { $0.id == node.id }) {
            breadcrumbs = Array(breadcrumbs.prefix(through: idx))
        } else {
            breadcrumbs.append(node)
        }
    }
    
    // MARK: - Navigation: Drill Up
    public func drillUp() {
        guard breadcrumbs.count > 1 else { return }
        breadcrumbs.removeLast()
        currentNode = breadcrumbs.last
        selectedNode = nil
        hoveredNode = nil
    }
    
    // MARK: - Navigation: Jump to Breadcrumb
    public func navigateTo(breadcrumb: DiskNode) {
        guard let idx = breadcrumbs.firstIndex(where: { $0.id == breadcrumb.id }) else { return }
        breadcrumbs = Array(breadcrumbs.prefix(through: idx))
        currentNode = breadcrumb
        selectedNode = nil
        hoveredNode = nil
    }
    
    // MARK: - Fast Disk Space Scan
    public func startScan(at customURL: URL? = nil) async {
        guard !isScanning else { return }
        isScanning = true
        scanProgress = 0.0
        statusMessage = "Analyzing directory structure..."
        
        let targetURL = customURL ?? FileManager.default.homeDirectoryForCurrentUser
        let displayName = targetURL.path == FileManager.default.homeDirectoryForCurrentUser.path ? "Home (~)" : targetURL.lastPathComponent
        
        let scannedTree = await Task.detached(priority: .userInitiated) {
            return Self.scanDirectoryHierarchy(url: targetURL, displayName: displayName, maxDepth: 2)
        }.value
        
        self.rootNode = scannedTree
        self.currentNode = scannedTree
        self.breadcrumbs = [scannedTree]
        self.isScanning = false
        self.scanProgress = 1.0
        self.statusMessage = "Analysis complete: \(scannedTree.formattedSize) mapped across \(scannedTree.children.count) primary items."
    }
    
    // MARK: - Recursive Directory Hierarchy Scanner
    private nonisolated static func scanDirectoryHierarchy(
        url: URL,
        displayName: String,
        maxDepth: Int,
        currentDepth: Int = 0
    ) -> DiskNode {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return DiskNode(url: url, name: displayName, path: url.path, isDirectory: false)
        }
        
        if !isDir.boolValue {
            let size = fileSize(url: url, fm: fm)
            return DiskNode(url: url, name: displayName, path: url.path, isDirectory: false, size: size, fileCount: 1)
        }
        
        // Scan Directory Contents
        let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .isPackageKey, .isSymbolicLinkKey]
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ) else {
            let size = fastDirectorySize(url: url, fm: fm)
            return DiskNode(url: url, name: displayName, path: url.path, isDirectory: true, size: size)
        }
        
        var childNodes: [DiskNode] = []
        var totalFolderSize: Int64 = 0
        var totalFilesCount: Int = 0
        
        for itemURL in contents {
            let itemName = itemURL.lastPathComponent
            
            // Skip common virtual or problematic mounts
            if itemName.hasPrefix(".") || itemName == ".Trash" { continue }
            
            var itemIsDir: ObjCBool = false
            if fm.fileExists(atPath: itemURL.path, isDirectory: &itemIsDir) {
                if itemIsDir.boolValue {
                    let childNode: DiskNode
                    if currentDepth < maxDepth {
                        childNode = scanDirectoryHierarchy(
                            url: itemURL,
                            displayName: itemName,
                            maxDepth: maxDepth,
                            currentDepth: currentDepth + 1
                        )
                    } else {
                        let sz = fastDirectorySize(url: itemURL, fm: fm)
                        childNode = DiskNode(
                            url: itemURL,
                            name: itemName,
                            path: itemURL.path,
                            isDirectory: true,
                            size: sz
                        )
                    }
                    
                    if childNode.size > 0 {
                        childNodes.append(childNode)
                        totalFolderSize += childNode.size
                        totalFilesCount += max(1, childNode.fileCount)
                    }
                } else {
                    let sz = fileSize(url: itemURL, fm: fm)
                    if sz > 0 {
                        let fileNode = DiskNode(
                            url: itemURL,
                            name: itemName,
                            path: itemURL.path,
                            isDirectory: false,
                            size: sz,
                            fileCount: 1
                        )
                        childNodes.append(fileNode)
                        totalFolderSize += sz
                        totalFilesCount += 1
                    }
                }
            }
        }
        
        // Sort descending by size
        childNodes.sort { $0.size > $1.size }
        
        // Group very small items (< 0.5% of total or < 5MB) into "Other Small Items" if there are many
        if childNodes.count > 15 && totalFolderSize > 50 * 1024 * 1024 {
            let threshold = max(Int64(5 * 1024 * 1024), Int64(Double(totalFolderSize) * 0.005))
            let significant = childNodes.filter { $0.size >= threshold }
            let tiny = childNodes.filter { $0.size < threshold }
            
            if !tiny.isEmpty && significant.count >= 5 {
                let tinySum = tiny.reduce(Int64(0)) { $0 + $1.size }
                let tinyFiles = tiny.reduce(0) { $0 + $1.fileCount }
                let otherNode = DiskNode(
                    url: url.appendingPathComponent("Other Items"),
                    name: "Other Items (\(tiny.count))",
                    path: url.path,
                    isDirectory: true,
                    size: tinySum,
                    fileCount: tinyFiles,
                    children: tiny,
                    color: Color.secondary.opacity(0.7)
                )
                childNodes = significant + [otherNode]
            }
        }
        
        // Assign palette colors to primary children
        for (i, child) in childNodes.enumerated() {
            child.color = DiskColorPalette.color(for: i)
        }
        
        let root = DiskNode(
            url: url,
            name: displayName,
            path: url.path,
            isDirectory: true,
            size: totalFolderSize,
            fileCount: totalFilesCount,
            children: childNodes,
            level: currentDepth
        )
        
        for child in childNodes {
            child.parent = root
        }
        
        return root
    }
    
    // Fast directory size calculator
    private nonisolated static func fastDirectorySize(url: URL, fm: FileManager) -> Int64 {
        var totalBytes: Int64 = 0
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey]
        
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else { return 0 }
        
        var filesExamined = 0
        for case let fileURL as URL in enumerator {
            filesExamined += 1
            if filesExamined > 5000 {
                // Safeguard against gigantic endless trees
                break
            }
            if let vals = try? fileURL.resourceValues(forKeys: keys), vals.isRegularFile == true {
                let sz = Int64(vals.totalFileAllocatedSize ?? vals.fileAllocatedSize ?? vals.fileSize ?? 0)
                totalBytes += sz
            }
        }
        return totalBytes
    }
    
    private nonisolated static func fileSize(url: URL, fm: FileManager) -> Int64 {
        guard let vals = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey]) else {
            return 0
        }
        return Int64(vals.totalFileAllocatedSize ?? vals.fileAllocatedSize ?? vals.fileSize ?? 0)
    }
    
    // MARK: - Open Folder Picker
    public func pickCustomFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Analyze Folder"
        panel.message = "Choose a directory to visualize in Disk Space"
        
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await startScan(at: url)
            }
        }
    }
    
    // MARK: - Reveal in Finder
    public func revealInFinder(node: DiskNode) {
        NSWorkspace.shared.activateFileViewerSelecting([node.url])
    }
    
    // MARK: - Open in Default App
    public func openItem(node: DiskNode) {
        NSWorkspace.shared.open(node.url)
    }
}
