import Foundation

// MARK: - Minimal Lightweight Test Framework
class TestSuite {
    var passedCount = 0
    var failedCount = 0
    let suiteName: String
    
    init(_ name: String) {
        self.suiteName = name
        print("\n========================================================")
        print("  Running Test Suite: \(suiteName)")
        print("========================================================")
    }
    
    func assert(_ condition: Bool, _ testName: String, file: String = #file, line: Int = #line) {
        if condition {
            passedCount += 1
            print("  ✅ [PASS] \(testName)")
        } else {
            failedCount += 1
            print("  ❌ [FAIL] \(testName) (at \(URL(fileURLWithPath: file).lastPathComponent):\(line))")
        }
    }
    
    func printSummary() -> Bool {
        print("--------------------------------------------------------")
        print("  \(suiteName) Summary: \(passedCount) Passed, \(failedCount) Failed")
        print("--------------------------------------------------------\n")
        return failedCount == 0
    }
}

// MARK: - 1. Path Protection Logic Tests
func runPathProtectionTests() -> Bool {
    let suite = TestSuite("PathProtection Security Logic")
    
    let mockHome = URL(fileURLWithPath: "/Users/testuser")
    
    // Test 1: Root & System Critical Directories
    suite.assert(
        PathProtection.isProtected(url: URL(fileURLWithPath: "/"), homeDirectory: mockHome),
        "Root '/' must be protected"
    )
    suite.assert(
        PathProtection.isProtected(url: URL(fileURLWithPath: "/System"), homeDirectory: mockHome),
        "/System must be protected"
    )
    suite.assert(
        PathProtection.isProtected(url: URL(fileURLWithPath: "/System/Library"), homeDirectory: mockHome),
        "/System/Library must be protected"
    )
    suite.assert(
        PathProtection.isProtected(url: URL(fileURLWithPath: "/bin"), homeDirectory: mockHome),
        "/bin must be protected"
    )
    suite.assert(
        PathProtection.isProtected(url: URL(fileURLWithPath: "/sbin"), homeDirectory: mockHome),
        "/sbin must be protected"
    )
    suite.assert(
        PathProtection.isProtected(url: URL(fileURLWithPath: "/usr/bin"), homeDirectory: mockHome),
        "/usr/bin must be protected"
    )
    suite.assert(
        PathProtection.isProtected(url: URL(fileURLWithPath: "/usr/lib"), homeDirectory: mockHome),
        "/usr/lib must be protected"
    )
    suite.assert(
        PathProtection.isProtected(url: URL(fileURLWithPath: "/private/etc"), homeDirectory: mockHome),
        "/private/etc must be protected"
    )
    suite.assert(
        PathProtection.isProtected(url: URL(fileURLWithPath: "/Library"), homeDirectory: mockHome),
        "/Library must be protected"
    )
    suite.assert(
        PathProtection.isProtected(url: URL(fileURLWithPath: "/Applications"), homeDirectory: mockHome),
        "/Applications must be protected"
    )
    
    // Test 2: System & Protected Apple Applications
    suite.assert(
        PathProtection.isProtected(url: URL(fileURLWithPath: "/Applications/Safari.app"), homeDirectory: mockHome),
        "/Applications/Safari.app must be protected"
    )
    suite.assert(
        PathProtection.isProtected(url: URL(fileURLWithPath: "/Applications/Finder.app"), homeDirectory: mockHome),
        "/Applications/Finder.app must be protected"
    )
    suite.assert(
        PathProtection.isProtected(url: URL(fileURLWithPath: "/Applications/System Settings.app"), homeDirectory: mockHome),
        "/Applications/System Settings.app must be protected"
    )
    suite.assert(
        PathProtection.isProtected(url: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"), homeDirectory: mockHome),
        "/System/Applications apps must be protected"
    )
    
    // Test 3: User Home Root & Essential User Directories
    suite.assert(
        PathProtection.isProtected(url: mockHome, homeDirectory: mockHome),
        "User home directory itself must be protected"
    )
    suite.assert(
        PathProtection.isProtected(url: mockHome.appendingPathComponent("Desktop"), homeDirectory: mockHome),
        "~/Desktop must be protected"
    )
    suite.assert(
        PathProtection.isProtected(url: mockHome.appendingPathComponent("Documents"), homeDirectory: mockHome),
        "~/Documents must be protected"
    )
    suite.assert(
        PathProtection.isProtected(url: mockHome.appendingPathComponent("Downloads"), homeDirectory: mockHome),
        "~/Downloads root must be protected"
    )
    suite.assert(
        PathProtection.isProtected(url: mockHome.appendingPathComponent("Library"), homeDirectory: mockHome),
        "~/Library root must be protected"
    )
    suite.assert(
        PathProtection.isProtected(url: mockHome.appendingPathComponent("Pictures"), homeDirectory: mockHome),
        "~/Pictures root must be protected"
    )
    
    // Test 4: Sensitive User Files & Credentials
    suite.assert(
        PathProtection.isProtected(url: mockHome.appendingPathComponent(".ssh"), homeDirectory: mockHome),
        "~/.ssh folder must be protected"
    )
    suite.assert(
        PathProtection.isProtected(url: mockHome.appendingPathComponent(".ssh/id_rsa"), homeDirectory: mockHome),
        "~/.ssh/id_rsa must be protected"
    )
    suite.assert(
        PathProtection.isProtected(url: mockHome.appendingPathComponent(".ssh/known_hosts"), homeDirectory: mockHome),
        "~/.ssh/known_hosts must be protected"
    )
    suite.assert(
        PathProtection.isProtected(url: mockHome.appendingPathComponent(".gnupg"), homeDirectory: mockHome),
        "~/.gnupg must be protected"
    )
    suite.assert(
        PathProtection.isProtected(url: mockHome.appendingPathComponent(".zshrc"), homeDirectory: mockHome),
        "~/.zshrc shell configuration must be protected"
    )
    suite.assert(
        PathProtection.isProtected(url: mockHome.appendingPathComponent(".bash_profile"), homeDirectory: mockHome),
        "~/.bash_profile shell config must be protected"
    )
    suite.assert(
        PathProtection.isProtected(url: mockHome.appendingPathComponent("Library/Keychains"), homeDirectory: mockHome),
        "~/Library/Keychains must be protected"
    )
    suite.assert(
        PathProtection.isProtected(url: mockHome.appendingPathComponent("Library/Keychains/login.keychain-db"), homeDirectory: mockHome),
        "Keychain DB files must be protected"
    )
    
    // Test 5: Safe Cleanable Paths (Must NOT be protected)
    suite.assert(
        !PathProtection.isProtected(url: mockHome.appendingPathComponent("Library/Caches/com.spotify.client"), homeDirectory: mockHome),
        "~/Library/Caches/com.spotify.client should be safe to clean"
    )
    suite.assert(
        !PathProtection.isProtected(url: mockHome.appendingPathComponent("Library/Caches/Google/Chrome"), homeDirectory: mockHome),
        "~/Library/Caches/Google/Chrome should be safe to clean"
    )
    suite.assert(
        !PathProtection.isProtected(url: mockHome.appendingPathComponent("Library/Developer/Xcode/DerivedData"), homeDirectory: mockHome),
        "Xcode DerivedData should be safe to clean"
    )
    suite.assert(
        !PathProtection.isProtected(url: mockHome.appendingPathComponent(".Trash/sample_junk.txt"), homeDirectory: mockHome),
        "~/.Trash items should be safe to clean"
    )
    suite.assert(
        !PathProtection.isProtected(url: mockHome.appendingPathComponent("Downloads/installer.dmg"), homeDirectory: mockHome),
        "Files inside ~/Downloads should be safe to delete"
    )
    
    // Test 6: Path Partitioning (Safe vs Blocked Batch)
    let mixedURLs = [
        URL(fileURLWithPath: "/System/Library"),
        mockHome.appendingPathComponent(".ssh/id_rsa"),
        mockHome.appendingPathComponent("Library/Caches/com.apple.Safari"),
        mockHome.appendingPathComponent("Downloads/large_video.mov"),
        URL(fileURLWithPath: "/")
    ]
    let (safe, blocked) = PathProtection.partitionSafeAndBlocked(urls: mixedURLs, homeDirectory: mockHome)
    suite.assert(safe.count == 2, "Batch partitioning should find 2 safe URLs (Caches and Downloads video)")
    suite.assert(blocked.count == 3, "Batch partitioning should block 3 URLs (System, SSH key, and Root)")
    
    return suite.printSummary()
}

// MARK: - 2. Size Calculation Engine Tests
func runSizeCalculationTests() -> Bool {
    let suite = TestSuite("SizeCalculation Sizing Engine")
    let fm = FileManager.default
    let tempDir = fm.temporaryDirectory.appendingPathComponent("TidyMacTest_\(UUID().uuidString)")
    
    try? fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer {
        try? fm.removeItem(at: tempDir)
    }
    
    // Test 1: Non-existent file
    let nonExistentURL = tempDir.appendingPathComponent("does_not_exist.bin")
    let nonExistentSize = SizeCalculator.calculateSize(of: nonExistentURL, fm: fm)
    suite.assert(
        nonExistentSize.bytes == 0 && nonExistentSize.filesCount == 0,
        "Non-existent path must return 0 bytes and 0 files"
    )
    
    // Test 2: Empty file
    let emptyFileURL = tempDir.appendingPathComponent("empty.txt")
    fm.createFile(atPath: emptyFileURL.path, contents: Data(), attributes: nil)
    let emptySize = SizeCalculator.calculateSize(of: emptyFileURL, fm: fm)
    suite.assert(
        emptySize.bytes == 0 && emptySize.filesCount == 1,
        "Empty file must return 0 bytes and 1 file count"
    )
    
    // Test 3: Single file with known byte count
    let singleFileURL = tempDir.appendingPathComponent("data_1024.bin")
    let data1024 = Data(repeating: 0x41, count: 1024)
    fm.createFile(atPath: singleFileURL.path, contents: data1024, attributes: nil)
    let singleSize = SizeCalculator.calculateSize(of: singleFileURL, fm: fm)
    suite.assert(
        singleSize.bytes >= 1024 && singleSize.filesCount == 1,
        "Single 1024-byte file must measure >= 1024 bytes and 1 file count"
    )
    
    // Test 4: Directory with nested files and folders
    let subDirA = tempDir.appendingPathComponent("SubDirA")
    let subDirB = subDirA.appendingPathComponent("SubDirB")
    try? fm.createDirectory(at: subDirB, withIntermediateDirectories: true)
    
    let file1Data = Data(repeating: 0x42, count: 2048)
    let file2Data = Data(repeating: 0x43, count: 4096)
    let file1URL = subDirA.appendingPathComponent("file1.bin")
    let file2URL = subDirB.appendingPathComponent("file2.bin")
    fm.createFile(atPath: file1URL.path, contents: file1Data, attributes: nil)
    fm.createFile(atPath: file2URL.path, contents: file2Data, attributes: nil)
    
    let dirSize = SizeCalculator.calculateSize(of: subDirA, fm: fm)
    suite.assert(
        dirSize.filesCount == 2,
        "Nested directory tree must count exactly 2 regular files"
    )
    suite.assert(
        dirSize.bytes >= 6144, // 2048 + 4096 = 6144 bytes
        "Nested directory tree must measure sum of nested files (>= 6144 bytes)"
    )
    
    // Test 5: Symlink safety (prevents recursion)
    let symlinkURL = subDirA.appendingPathComponent("loop_link")
    try? fm.createSymbolicLink(at: symlinkURL, withDestinationURL: subDirA)
    let symlinkDirSize = SizeCalculator.calculateSize(of: subDirA, fm: fm, followSymlinks: false)
    suite.assert(
        symlinkDirSize.bytes >= 6144,
        "Directory with cyclic symlink must compute safely without crashing or hanging"
    )
    
    // Test 6: Byte Count Formatting
    suite.assert(
        SizeCalculator.formatBytes(0).contains("0") || SizeCalculator.formatBytes(0).contains("Zero"),
        "0 bytes formatting produces valid zero display"
    )
    let formattedMB = SizeCalculator.formatBytes(15 * 1024 * 1024)
    suite.assert(
        formattedMB.contains("15") && (formattedMB.contains("MB") || formattedMB.contains("M")),
        "15 MB formatting produces '15 MB': got \(formattedMB)"
    )
    
    return suite.printSummary()
}

// MARK: - 3. Security, Shell Escaping & Privilege Sanitization Tests
func runSecurityAndEscapingTests() -> Bool {
    let suite = TestSuite("Security & Shell Sanitization Logic")
    let mockHome = URL(fileURLWithPath: "/Users/testuser")
    
    // Test 1: Valid launch item locations
    suite.assert(
        SecurityEscaping.isValidLaunchItemPath("/Library/LaunchDaemons/com.apple.test.plist", homeDirectory: mockHome),
        "Standard /Library/LaunchDaemons .plist path must be valid"
    )
    suite.assert(
        SecurityEscaping.isValidLaunchItemPath("/Library/LaunchAgents/com.service.agent.plist", homeDirectory: mockHome),
        "Standard /Library/LaunchAgents .plist path must be valid"
    )
    suite.assert(
        SecurityEscaping.isValidLaunchItemPath("/Users/testuser/Library/LaunchAgents/com.user.agent.plist", homeDirectory: mockHome),
        "User ~/Library/LaunchAgents .plist path must be valid"
    )
    suite.assert(
        SecurityEscaping.isValidLaunchItemPath("/Library/LaunchDaemons/com.service.plist.disabled", homeDirectory: mockHome),
        "Launch daemon with .plist.disabled suffix must be valid"
    )
    
    // Test 2: Invalid or dangerous launch item paths
    suite.assert(
        !SecurityEscaping.isValidLaunchItemPath("/etc/launchd.conf", homeDirectory: mockHome),
        "Path outside allowed directories (/etc) must be rejected"
    )
    suite.assert(
        !SecurityEscaping.isValidLaunchItemPath("/bin/sh", homeDirectory: mockHome),
        "System executable (/bin/sh) must be rejected"
    )
    suite.assert(
        !SecurityEscaping.isValidLaunchItemPath("/Library/LaunchDaemons/../../etc/passwd", homeDirectory: mockHome),
        "Directory traversal /../ in path must be rejected"
    )
    suite.assert(
        !SecurityEscaping.isValidLaunchItemPath("/Library/LaunchDaemons/malicious.sh", homeDirectory: mockHome),
        "Non-plist extension (.sh) must be rejected"
    )
    suite.assert(
        !SecurityEscaping.isValidLaunchItemPath("/Library/LaunchDaemons/test\0hidden.plist", homeDirectory: mockHome),
        "Path containing null byte must be rejected"
    )
    suite.assert(
        !SecurityEscaping.isValidLaunchItemPath("/Library/LaunchDaemons/test\ninjection.plist", homeDirectory: mockHome),
        "Path containing newline must be rejected"
    )
    
    // Test 3: POSIX single-quote shell escaping
    let plainString = "/path/to/my file.plist"
    suite.assert(
        SecurityEscaping.posixShellQuote(plainString) == "'/path/to/my file.plist'",
        "Plain path is cleanly wrapped in single quotes"
    )
    
    let injectionString = "file.plist\" && rm -rf / && echo \""
    let quotedInjection = SecurityEscaping.posixShellQuote(injectionString)
    suite.assert(
        quotedInjection == "'file.plist\" && rm -rf / && echo \"'",
        "Double-quotes, ampersands, and commands cannot break single-quote enclosure"
    )
    
    let singleQuoteInjection = "user's'file.plist"
    let safeSingleQuote = SecurityEscaping.posixShellQuote(singleQuoteInjection)
    suite.assert(
        safeSingleQuote == "'user'\\''s'\\''file.plist'",
        "Internal single quotes are safely escaped as '\\''"
    )
    
    // Test 4: AppleScript string literal escaping
    let scriptString = "echo \"Hello World\" \\ test"
    let escapedScript = SecurityEscaping.appleScriptStringEscape(scriptString)
    suite.assert(
        escapedScript == "echo \\\"Hello World\\\" \\\\ test",
        "AppleScript escaping correctly escapes double-quotes and backslashes"
    )
    
    return suite.printSummary()
}

// MARK: - 4. Executable Lookup (No Shell Invocation) Tests
func runExecutableLookupTests() -> Bool {
    let suite = TestSuite("Executable Lookup Safety (No Subshells)")
    
    // Test 1: Standard binary resolution
    let shPath = SecurityEscaping.findExecutable(named: "sh")
    suite.assert(
        shPath != nil && (shPath == "/bin/sh" || shPath == "/usr/bin/sh"),
        "Resolves system binary 'sh' directly from disk: got \(shPath ?? "nil")"
    )
    
    let zshPath = SecurityEscaping.findExecutable(named: "zsh")
    suite.assert(
        zshPath != nil && (zshPath == "/bin/zsh" || zshPath == "/usr/bin/zsh"),
        "Resolves system binary 'zsh' directly from disk: got \(zshPath ?? "nil")"
    )
    
    // Test 2: Non-existent tool returns nil safely
    let bogus = SecurityEscaping.findExecutable(named: "tidymac_nonexistent_scanner_tool_xyz")
    suite.assert(
        bogus == nil,
        "Non-existent tool name safely returns nil"
    )
    
    // Test 3: Path injection attempts return nil immediately
    let pathInjection = SecurityEscaping.findExecutable(named: "../../bin/sh")
    suite.assert(
        pathInjection == nil,
        "Executable names with slashes are immediately rejected"
    )
    
    let commandInjection = SecurityEscaping.findExecutable(named: "sh; whoami")
    suite.assert(
        commandInjection == nil,
        "Executable names with shell separators are safely rejected"
    )
    
    return suite.printSummary()
}

// MARK: - 5. Deletion & Activity Log Tests
func runDeletionLogManagerTests() -> Bool {
    let suite = TestSuite("Deletion & Activity Log Persistence")
    
    let manager = DeletionLogManager.shared
    
    // Test 1: Logging a simulated deletion
    manager.log(
        sourceModule: "TestModule",
        path: "/tmp/testfile.log",
        sizeBytes: 1024,
        destination: .simulated,
        isSuccess: true
    )
    
    // Allow brief async persistence
    usleep(50_000)
    
    suite.assert(
        !manager.records.isEmpty,
        "Deletion records are added to manager memory"
    )
    
    if let first = manager.records.first {
        suite.assert(
            first.sourceModule == "TestModule" && first.sizeBytes == 1024,
            "Logged record contains expected module and size"
        )
        suite.assert(
            first.destination == .simulated && first.isSuccess == true,
            "Logged record contains expected destination and status"
        )
    }
    
    // Test 2: Logging a Trash deletion
    manager.log(
        sourceModule: "Privacy",
        path: "/tmp/cache.db",
        sizeBytes: 2048,
        destination: .trash,
        isSuccess: true
    )
    
    usleep(50_000)
    suite.assert(
        manager.records.contains { $0.destination == .trash && $0.sourceModule == "Privacy" },
        "Trash deletion logged and queryable"
    )
    
    return suite.printSummary()
}

// MARK: - 6. Smart Scan Truthfulness Tests
func runSmartScanTruthfulnessTests() -> Bool {
    let suite = TestSuite("Smart Scan Measurement Truthfulness (Zero Fake Space)")
    
    // Test 1: Storage Cleanable calculation strictly sums disk storage
    var summary = SmartScanSummary()
    summary.junkBytes = 100 * 1024 * 1024
    summary.largeFilesBytes = 50 * 1024 * 1024
    summary.privacyBytes = 10 * 1024 * 1024
    summary.purgeableRAMBytes = 800 * 1024 * 1024 // 800 MB of inactive RAM
    
    suite.assert(
        summary.totalCleanableBytes == (160 * 1024 * 1024),
        "totalCleanableBytes strictly sums disk storage (160 MB) and excludes RAM"
    )
    
    // Test 2: Deselecting junk updates cleanable disk total
    summary.isJunkSelected = false
    suite.assert(
        summary.totalCleanableBytes == (60 * 1024 * 1024),
        "Deselecting module properly excludes its bytes from disk cleanable total"
    )
    
    // Test 3: Formatting matches cleanable disk bytes
    suite.assert(
        summary.formattedTotalCleanable.contains("62") || summary.formattedTotalCleanable.contains("60") || summary.formattedTotalCleanable.contains("63"),
        "Formatted cleanable total reflects true disk bytes: got \(summary.formattedTotalCleanable)"
    )
    
    return suite.printSummary()
}

// MARK: - Main Execution
print("\n🚀 Starting TidyMac Unit Tests Execution...")
let startTime = Date()

let pathSuccess = runPathProtectionTests()
let sizeSuccess = runSizeCalculationTests()
let securitySuccess = runSecurityAndEscapingTests()
let execSuccess = runExecutableLookupTests()
let deletionLogSuccess = runDeletionLogManagerTests()
let smartScanTruthSuccess = runSmartScanTruthfulnessTests()

let elapsed = Date().timeIntervalSince(startTime)
let allPassed = pathSuccess && sizeSuccess && securitySuccess && execSuccess && deletionLogSuccess && smartScanTruthSuccess

print("========================================================")
if allPassed {
    print(String(format: "🎉 ALL 6 TEST SUITES PASSED in %.3f seconds!", elapsed))
    print("========================================================\n")
    exit(0)
} else {
    print(String(format: "❌ SOME UNIT TESTS FAILED in %.3f seconds.", elapsed))
    print("========================================================\n")
    exit(1)
}
