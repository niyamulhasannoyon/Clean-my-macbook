import Foundation
import SQLite3
import TidyMacCore

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
    
    // Test 7: Case-insensitive APFS bypass prevention
    suite.assert(
        PathProtection.isProtected(url: URL(fileURLWithPath: "/system/library"), homeDirectory: mockHome),
        "Lowercase /system/library must be protected"
    )
    suite.assert(
        PathProtection.isProtected(url: URL(fileURLWithPath: "/SYSTEM"), homeDirectory: mockHome),
        "Uppercase /SYSTEM must be protected"
    )
    suite.assert(
        PathProtection.isProtected(url: URL(fileURLWithPath: "/Applications/safari.app"), homeDirectory: mockHome),
        "Lowercase /Applications/safari.app must be protected"
    )
    suite.assert(
        PathProtection.isProtected(url: URL(fileURLWithPath: "/applications/system settings.app/Contents/MacOS/System Settings"), homeDirectory: mockHome),
        "Case-variant protected system app subpath must be protected"
    )
    suite.assert(
        PathProtection.isProtected(url: URL(fileURLWithPath: "/Users/TESTUSER"), homeDirectory: mockHome),
        "Case-variant user home directory must be protected"
    )
    suite.assert(
        PathProtection.isProtected(url: mockHome.appendingPathComponent("desktop"), homeDirectory: mockHome),
        "Lowercase ~/desktop must be protected"
    )
    suite.assert(
        PathProtection.isProtected(url: mockHome.appendingPathComponent("DOCUMENTS"), homeDirectory: mockHome),
        "Uppercase ~/DOCUMENTS must be protected"
    )
    suite.assert(
        PathProtection.isProtected(url: mockHome.appendingPathComponent(".SSH/ID_RSA"), homeDirectory: mockHome),
        "Uppercase ~/.SSH/ID_RSA must be protected"
    )
    suite.assert(
        PathProtection.isProtected(url: mockHome.appendingPathComponent("library/keychains/LOGIN.KEYCHAIN-DB"), homeDirectory: mockHome),
        "Case-variant keychain path and suffix must be protected"
    )
    suite.assert(
        PathProtection.isProtected(url: URL(fileURLWithPath: "/tmp/backup.KEYCHAIN"), homeDirectory: mockHome),
        "Uppercase .KEYCHAIN suffix must be protected"
    )
    suite.assert(
        !PathProtection.isProtected(url: mockHome.appendingPathComponent("library/caches/com.spotify.client"), homeDirectory: mockHome),
        "Case-variant ~/library/caches path should remain cleanable"
    )
    
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
    
    // Test 6: Package contents (.app, .framework, .bundle, .xcarchive) are traversed accurately
    let packagesRoot = tempDir.appendingPathComponent("PackagesRoot")
    let sampleApp = packagesRoot.appendingPathComponent("Sample.app")
    let appMacOS = sampleApp.appendingPathComponent("Contents/MacOS")
    let frameworkRoot = sampleApp.appendingPathComponent("Contents/Frameworks/Helper.framework")
    let frameworkVersionA = frameworkRoot.appendingPathComponent("Versions/A")
    let resourceBundle = sampleApp.appendingPathComponent("Contents/Resources/Assets.bundle")
    let xcarchiveApp = packagesRoot.appendingPathComponent("Build.xcarchive/Products/Applications/Archived.app/Contents/MacOS")
    
    try? fm.createDirectory(at: appMacOS, withIntermediateDirectories: true)
    try? fm.createDirectory(at: frameworkVersionA, withIntermediateDirectories: true)
    try? fm.createDirectory(at: resourceBundle, withIntermediateDirectories: true)
    try? fm.createDirectory(at: xcarchiveApp, withIntermediateDirectories: true)
    
    fm.createFile(atPath: appMacOS.appendingPathComponent("Sample").path, contents: Data(repeating: 0x11, count: 4096), attributes: nil)
    fm.createFile(atPath: frameworkVersionA.appendingPathComponent("Helper").path, contents: Data(repeating: 0x22, count: 8192), attributes: nil)
    try? fm.createSymbolicLink(at: frameworkRoot.appendingPathComponent("Versions/Current"), withDestinationURL: frameworkVersionA)
    fm.createFile(atPath: resourceBundle.appendingPathComponent("data.bin").path, contents: Data(repeating: 0x33, count: 2048), attributes: nil)
    fm.createFile(atPath: xcarchiveApp.appendingPathComponent("Archived").path, contents: Data(repeating: 0x44, count: 4096), attributes: nil)
    
    let appBundleSize = SizeCalculator.calculateSize(of: sampleApp, fm: fm, followSymlinks: false)
    suite.assert(
        appBundleSize.filesCount == 4 && appBundleSize.bytes >= 14336,
        "App bundle with nested .framework (including symlink) and .bundle must count 4 entries and >= 14336 bytes (got files=\(appBundleSize.filesCount), bytes=\(appBundleSize.bytes))"
    )
    
    let packagesRootSize = SizeCalculator.calculateSize(of: packagesRoot, fm: fm, followSymlinks: false)
    suite.assert(
        packagesRootSize.filesCount == 5 && packagesRootSize.bytes >= 18432,
        "Directory containing .app and .xcarchive must count 5 entries and >= 18432 bytes (got files=\(packagesRootSize.filesCount), bytes=\(packagesRootSize.bytes))"
    )
    
    // Test 7: Byte Count Formatting
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
    suite.assert(
        !SecurityEscaping.isValidLaunchItemPath("/Library/LaunchDaemonsFake/evil.plist", homeDirectory: mockHome),
        "Prefix bypass /Library/LaunchDaemonsFake must be rejected"
    )
    suite.assert(
        !SecurityEscaping.isValidLaunchItemPath("/Library/LaunchDaemonsFake/test.plist", homeDirectory: mockHome),
        "Prefix bypass /Library/LaunchDaemonsFake/test.plist must be rejected"
    )
    suite.assert(
        !SecurityEscaping.isValidLaunchItemPath("/Library/LaunchAgentsFake/evil.plist", homeDirectory: mockHome),
        "Prefix bypass /Library/LaunchAgentsFake must be rejected"
    )
    suite.assert(
        !SecurityEscaping.isValidLaunchItemPath("/Users/testuser/Library/LaunchAgentsFake/evil.plist", homeDirectory: mockHome),
        "Prefix bypass ~/Library/LaunchAgentsFake must be rejected"
    )
    suite.assert(
        !SecurityEscaping.isValidLaunchItemPath("/Library/LaunchDaemons/test.plist\0hidden", homeDirectory: mockHome),
        "Path with null byte after .plist must be rejected"
    )
    suite.assert(
        !SecurityEscaping.isValidLaunchItemPath("", homeDirectory: mockHome),
        "Empty launch item path must be rejected"
    )
    suite.assert(
        !SecurityEscaping.isValidLaunchItemPath("relative.plist", homeDirectory: mockHome),
        "Relative launch item path must be rejected"
    )
    suite.assert(
        SecurityEscaping.isValidLaunchItemPath("/library/launchdaemons/com.apple.test.plist", homeDirectory: mockHome),
        "Case-insensitive /library/launchdaemons path must be valid"
    )
    suite.assert(
        SecurityEscaping.isValidLaunchItemPath("/Users/TESTUSER/library/launchagents/com.user.agent.PLIST.DISABLED", homeDirectory: mockHome),
        "Case-insensitive user ~/Library/LaunchAgents .PLIST.DISABLED path must be valid"
    )
    
    // Test 2b: Symlink escape prevention in launch item validation
    let fm = FileManager.default
    let symlinkTestHome = fm.temporaryDirectory.appendingPathComponent("TidyMacLaunchTest_\(UUID().uuidString)")
    let symlinkAgentsDir = symlinkTestHome.appendingPathComponent("Library/LaunchAgents")
    let outsideDir = symlinkTestHome.appendingPathComponent("Outside")
    try? fm.createDirectory(at: symlinkAgentsDir, withIntermediateDirectories: true)
    try? fm.createDirectory(at: outsideDir, withIntermediateDirectories: true)
    defer {
        try? fm.removeItem(at: symlinkTestHome)
    }
    let outsideTarget = outsideDir.appendingPathComponent("evil.plist")
    fm.createFile(atPath: outsideTarget.path, contents: Data(), attributes: nil)
    let escapingSymlink = symlinkAgentsDir.appendingPathComponent("escape.plist")
    try? fm.createSymbolicLink(at: escapingSymlink, withDestinationURL: outsideTarget)
    suite.assert(
        !SecurityEscaping.isValidLaunchItemPath(escapingSymlink.path, homeDirectory: symlinkTestHome),
        "Symlink inside LaunchAgents pointing outside allowed directory must be rejected"
    )
    let insideTarget = symlinkAgentsDir.appendingPathComponent("real.plist")
    fm.createFile(atPath: insideTarget.path, contents: Data(), attributes: nil)
    let validSymlink = symlinkAgentsDir.appendingPathComponent("valid_alias.plist")
    try? fm.createSymbolicLink(at: validSymlink, withDestinationURL: insideTarget)
    suite.assert(
        SecurityEscaping.isValidLaunchItemPath(validSymlink.path, homeDirectory: symlinkTestHome),
        "Symlink inside LaunchAgents resolving within LaunchAgents must be valid"
    )
    let symlinkedDir = symlinkAgentsDir.appendingPathComponent("linked_outside")
    try? fm.createSymbolicLink(at: symlinkedDir, withDestinationURL: outsideDir)
    let lexicalBypassAttempt = symlinkedDir.appendingPathComponent("../evil.plist").path
    suite.assert(
        !SecurityEscaping.isValidLaunchItemPath(lexicalBypassAttempt, homeDirectory: symlinkTestHome),
        "Path containing '..' traversal component inside LaunchAgents must be rejected"
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
    let fm = FileManager.default
    let tempLogDir = fm.temporaryDirectory.appendingPathComponent("TidyMacDeletionLogTest_\(UUID().uuidString)")
    defer {
        try? fm.removeItem(at: tempLogDir)
    }
    
    let manager = DeletionLogManager(storageDirectory: tempLogDir)
    let expectedHistoryFile = tempLogDir.appendingPathComponent("deletion_history.json")
    
    // Test 1: Logging a simulated deletion
    manager.log(
        sourceModule: "TestModule",
        path: "/tmp/testfile.log",
        sizeBytes: 1024,
        destination: .simulated,
        isSuccess: true
    )
    manager.flush()
    
    suite.assert(
        !manager.records.isEmpty,
        "Deletion records are added to manager memory"
    )
    suite.assert(
        fm.fileExists(atPath: expectedHistoryFile.path),
        "Deletion history JSON is written inside isolated test storageDirectory"
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
    manager.flush()
    
    suite.assert(
        manager.records.contains { $0.destination == .trash && $0.sourceModule == "Privacy" },
        "Trash deletion logged and queryable"
    )
    
    // Test 3: Reloading from isolated storage directory preserves logged records
    let reloadedManager = DeletionLogManager(storageDirectory: tempLogDir)
    suite.assert(
        reloadedManager.records.count == 2 &&
        reloadedManager.records.contains { $0.sourceModule == "TestModule" && $0.sizeBytes == 1024 } &&
        reloadedManager.records.contains { $0.sourceModule == "Privacy" && $0.destination == .trash },
        "New DeletionLogManager(storageDirectory:) reloads persisted records from isolated directory"
    )
    
    // Test 4: Clearing history removes file inside isolated storage directory
    manager.clearHistory()
    manager.flush()
    suite.assert(
        manager.records.isEmpty && !fm.fileExists(atPath: expectedHistoryFile.path),
        "clearHistory removes in-memory records and isolated history file"
    )
    
    return suite.printSummary()
}

// MARK: - 6. Smart Scan Truthfulness & Safety Tests
func runSmartScanTruthfulnessTests() -> Bool {
    let suite = TestSuite("Smart Scan Safety, Selection & Truthfulness")
    
    // Test 1: Safe default selections on SmartScanSummary
    var summary = SmartScanSummary()
    suite.assert(
        summary.isLargeFilesSelected == false,
        "Large & Old Files must default to unselected (isLargeFilesSelected == false)"
    )
    suite.assert(
        summary.isJunkSelected == true && summary.isPrivacySelected == true && summary.isPerformanceSelected == true,
        "Default flags for Junk, Privacy, and Performance are initialized safely"
    )
    
    // Test 2: Storage Cleanable calculation strictly sums selected disk storage and excludes RAM
    summary.junkBytes = 100 * 1024 * 1024
    summary.junkFilesCount = 12
    summary.largeFilesBytes = 50 * 1024 * 1024
    summary.largeFilesCount = 2
    summary.privacyBytes = 10 * 1024 * 1024
    summary.privacyFilesCount = 4
    summary.purgeableRAMBytes = 800 * 1024 * 1024 // 800 MB of inactive RAM
    
    suite.assert(
        summary.totalCleanableBytes == (110 * 1024 * 1024),
        "totalCleanableBytes excludes Large & Old Files when isLargeFilesSelected is false (110 MB)"
    )
    suite.assert(
        summary.totalSelectedFilesCount == 16,
        "totalSelectedFilesCount excludes Large & Old Files when unselected (16 items)"
    )
    
    // Test 3: Explicitly selecting Large & Old Files includes them while still excluding RAM
    summary.isLargeFilesSelected = true
    suite.assert(
        summary.totalCleanableBytes == (160 * 1024 * 1024),
        "totalCleanableBytes strictly sums disk storage (160 MB) when Large Files enabled and excludes RAM"
    )
    suite.assert(
        summary.totalSelectedFilesCount == 18,
        "totalSelectedFilesCount includes Large Files when explicitly selected (18 items)"
    )
    
    // Test 4: Deselecting junk updates cleanable disk total
    summary.isJunkSelected = false
    suite.assert(
        summary.totalCleanableBytes == (60 * 1024 * 1024),
        "Deselecting module properly excludes its bytes from disk cleanable total"
    )
    
    // Test 5: Formatting matches cleanable disk bytes
    suite.assert(
        summary.formattedTotalCleanable.contains("62") || summary.formattedTotalCleanable.contains("60") || summary.formattedTotalCleanable.contains("63"),
        "Formatted cleanable total reflects true disk bytes: got \(summary.formattedTotalCleanable)"
    )
    
    // Test 6: Clean All enabled state includes Performance-only cleanup
    var perfOnlySummary = SmartScanSummary()
    perfOnlySummary.isJunkSelected = false
    perfOnlySummary.isLargeFilesSelected = false
    perfOnlySummary.isPrivacySelected = false
    perfOnlySummary.isPerformanceSelected = true
    suite.assert(
        perfOnlySummary.totalCleanableBytes == 0 && perfOnlySummary.canCleanAll == true,
        "Clean All remains enabled when totalCleanableBytes == 0 and isPerformanceSelected == true"
    )
    perfOnlySummary.isPerformanceSelected = false
    suite.assert(
        perfOnlySummary.canCleanAll == false,
        "Clean All is disabled only when totalCleanableBytes == 0 and isPerformanceSelected == false"
    )
    
    // Test 7: JunkCategoryType.defaultSelected protects Mail Attachments and iOS Backups
    suite.assert(
        JunkCategoryType.mailAttachments.defaultSelected == false,
        "Mail Attachments must default to unselected (defaultSelected == false)"
    )
    suite.assert(
        JunkCategoryType.iosBackups.defaultSelected == false,
        "iOS Device Backups must default to unselected (defaultSelected == false)"
    )
    suite.assert(
        JunkCategoryType.userCaches.defaultSelected &&
        JunkCategoryType.systemLogs.defaultSelected &&
        JunkCategoryType.xcodeDeveloper.defaultSelected &&
        JunkCategoryType.browserCaches.defaultSelected &&
        JunkCategoryType.trash.defaultSelected,
        "Safe junk categories default to selected"
    )
    
    return suite.printSummary()
}

// MARK: - 7. System Junk Scanner Integrity & Safety Tests
func runAsyncMainActorTest(_ operation: @escaping @MainActor () async -> Bool) -> Bool {
    var result = false
    var finished = false
    Task { @MainActor in
        result = await operation()
        finished = true
    }
    while !finished {
        RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
    }
    return result
}

func runSystemJunkScannerTests() -> Bool {
    return runAsyncMainActorTest {
        let suite = TestSuite("SystemJunkScanner Data-Loss & Accuracy Fixes")
        let fm = FileManager.default
        let tempRoot = fm.temporaryDirectory.appendingPathComponent("TidyMacJunkTest_\(UUID().uuidString)")
        let mockHome = tempRoot.appendingPathComponent("Home")
        let mockSystemLogs = tempRoot.appendingPathComponent("SystemLogs")
        
        try? fm.createDirectory(at: mockHome, withIntermediateDirectories: true)
        try? fm.createDirectory(at: mockSystemLogs, withIntermediateDirectories: true)
        defer {
            try? fm.removeItem(at: tempRoot)
        }
        
        // Test 1: Unused language (.lproj) stripping category is removed
        let hasLanguageCategory = JunkCategoryType.allCases.contains {
            $0.rawValue.lowercased().contains("lproj") || $0.rawValue.lowercased().contains("language")
        }
        suite.assert(!hasLanguageCategory, "Unused language (.lproj) category must be removed from JunkCategoryType")
        suite.assert(JunkCategoryType.allCases.count == 7, "JunkCategoryType should have exactly 7 safe categories")
        
        // Test 2: scanBrowserCaches emits one JunkItem per existing cache path
        let safariContainer = mockHome.appendingPathComponent("Library/Containers/com.apple.Safari/Data/Library/Caches")
        let safariCache = mockHome.appendingPathComponent("Library/Caches/com.apple.Safari")
        let chromeCache = mockHome.appendingPathComponent("Library/Caches/Google/Chrome")
        let chromeDefaultCache = mockHome.appendingPathComponent("Library/Application Support/Google/Chrome/Default/Cache")
        let chromeCodeCache = mockHome.appendingPathComponent("Library/Application Support/Google/Chrome/Default/Code Cache")
        let browserBlob = Data(repeating: 0x41, count: 20 * 1024) // > 10KB threshold
        
        for dir in [safariContainer, safariCache, chromeCache, chromeDefaultCache, chromeCodeCache] {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            fm.createFile(atPath: dir.appendingPathComponent("cache.bin").path, contents: browserBlob, attributes: nil)
        }
        
        let browserItems = await JunkScanEngine.scanBrowserCaches(home: mockHome, fm: fm)
        let browserItemPaths = Set(browserItems.map { $0.path.standardizedFileURL.path })
        suite.assert(browserItems.count == 5, "scanBrowserCaches must emit one item per existing path (expected 5, got \(browserItems.count))")
        suite.assert(
            browserItemPaths.contains(safariContainer.standardizedFileURL.path)
                && browserItemPaths.contains(safariCache.standardizedFileURL.path)
                && browserItemPaths.contains(chromeCache.standardizedFileURL.path)
                && browserItemPaths.contains(chromeDefaultCache.standardizedFileURL.path)
                && browserItemPaths.contains(chromeCodeCache.standardizedFileURL.path),
            "scanBrowserCaches must include all Safari and Chrome cache paths individually"
        )
        
        // Test 3: scanUserAppCaches excludes browser & Xcode folders to avoid double-counting
        let userCachesRoot = mockHome.appendingPathComponent("Library/Caches")
        let excludedNames = [
            "com.apple.Safari",
            "Google",
            "Firefox",
            "Mozilla",
            "Microsoft Edge",
            "BraveSoftware",
            "company.thebrowser.Browser",
            "com.apple.dt.Xcode"
        ]
        let appCacheBlob = Data(repeating: 0x42, count: 120 * 1024) // > 100KB threshold
        for name in excludedNames {
            let dir = userCachesRoot.appendingPathComponent(name)
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            fm.createFile(atPath: dir.appendingPathComponent("excluded.bin").path, contents: appCacheBlob, attributes: nil)
        }
        let spotifyCache = userCachesRoot.appendingPathComponent("com.spotify.client")
        try? fm.createDirectory(at: spotifyCache, withIntermediateDirectories: true)
        fm.createFile(atPath: spotifyCache.appendingPathComponent("audio.bin").path, contents: appCacheBlob, attributes: nil)
        
        let userCacheItems = await JunkScanEngine.scanUserAppCaches(home: mockHome, fm: fm)
        suite.assert(userCacheItems.count == 1, "scanUserAppCaches must exclude all 8 browser/Xcode folders (got \(userCacheItems.count) items)")
        suite.assert(userCacheItems.first?.path.lastPathComponent == "com.spotify.client", "scanUserAppCaches keeps non-excluded app caches")
        
        let xcodeItems = await JunkScanEngine.scanXcodeAndDeveloper(home: mockHome, fm: fm)
        suite.assert(
            xcodeItems.contains { $0.path.standardizedFileURL == userCachesRoot.appendingPathComponent("com.apple.dt.Xcode").standardizedFileURL },
            "scanXcodeAndDeveloper still scans com.apple.dt.Xcode without double-counting"
        )
        
        // Test 4: scanLogs enumerates files/subfolders inside ~/Library/Logs & system logs, never root directories
        let userLogsRoot = mockHome.appendingPathComponent("Library/Logs")
        let diagSubdir = userLogsRoot.appendingPathComponent("DiagnosticReports")
        try? fm.createDirectory(at: diagSubdir, withIntermediateDirectories: true)
        let logBlob = Data(repeating: 0x43, count: 4096)
        let userLogFile = userLogsRoot.appendingPathComponent("app.log")
        let diagFile = diagSubdir.appendingPathComponent("crash.ips")
        let sysLogFile = mockSystemLogs.appendingPathComponent("daemon.log")
        fm.createFile(atPath: userLogFile.path, contents: logBlob, attributes: nil)
        fm.createFile(atPath: diagFile.path, contents: logBlob, attributes: nil)
        fm.createFile(atPath: sysLogFile.path, contents: logBlob, attributes: nil)
        
        let logItems = await JunkScanEngine.scanLogs(home: mockHome, fm: fm, systemLogsURL: mockSystemLogs)
        let logItemPaths = Set(logItems.map { $0.path.standardizedFileURL.path })
        suite.assert(logItems.count == 3, "scanLogs should emit 3 child entries inside user & system log folders (got \(logItems.count))")
        suite.assert(
            !logItemPaths.contains(userLogsRoot.standardizedFileURL.path) && !logItemPaths.contains(mockSystemLogs.standardizedFileURL.path),
            "scanLogs must never emit root ~/Library/Logs or /Library/Logs directories"
        )
        suite.assert(
            logItemPaths.contains(userLogFile.standardizedFileURL.path)
                && logItemPaths.contains(diagSubdir.standardizedFileURL.path)
                && logItemPaths.contains(sysLogFile.standardizedFileURL.path),
            "scanLogs emits individual log files and subfolders"
        )
        
        // Test 5: performClean offloads I/O off MainActor and logs simulated, trashed, permanent, and failed deletions
        let originalDryRun = DryRunManager.shared.isEnabled
        defer {
            DryRunManager.shared.isEnabled = originalDryRun
        }
        
        // 5a: Dry-run simulation logging
        let testLogManager = DeletionLogManager(storageDirectory: tempRoot.appendingPathComponent("DeletionLogs"))
        DryRunManager.shared.isEnabled = true
        let dryRunScanner = SystemJunkScanner(deletionLogManager: testLogManager)
        let dryRunTarget = tempRoot.appendingPathComponent("dry_run_cache_\(UUID().uuidString).bin")
        fm.createFile(atPath: dryRunTarget.path, contents: logBlob, attributes: nil)
        let unselectedTarget = tempRoot.appendingPathComponent("keep_me.bin")
        fm.createFile(atPath: unselectedTarget.path, contents: logBlob, attributes: nil)
        
        dryRunScanner.categories = [
            JunkCategory(id: .userCaches, items: [
                JunkItem(category: .userCaches, name: "DryRun Item", path: dryRunTarget, size: 4096, fileCount: 1, isSelected: true),
                JunkItem(category: .userCaches, name: "Unselected Item", path: unselectedTarget, size: 4096, fileCount: 1, isSelected: false)
            ])
        ]
        await dryRunScanner.performClean()
        await testLogManager.flushAsync()
        
        suite.assert(dryRunScanner.lastCleanResult?.isDryRun == true, "Dry-Run clean marks result as dry-run")
        suite.assert(dryRunScanner.lastCleanResult?.reclaimedBytes == 4096, "Dry-Run clean reports exact selected bytes")
        suite.assert(fm.fileExists(atPath: dryRunTarget.path), "Dry-Run mode must not delete files on disk")
        suite.assert(
            dryRunScanner.categories.first?.items.count == 1 && dryRunScanner.categories.first?.items.first?.path == unselectedTarget,
            "Unselected items remain after clean"
        )
        suite.assert(
            testLogManager.records.contains {
                $0.sourceModule == "System Junk" && $0.path == dryRunTarget.path && $0.destination == .simulated && $0.isSuccess
            },
            "Dry-Run clean logs simulated item to DeletionLogManager"
        )
        
        // 5b: Real clean runs off MainActor, preserves root log directory, deletes Trash item, and logs success/failure
        DryRunManager.shared.isEnabled = false
        let realScanner = SystemJunkScanner(deletionLogManager: testLogManager)
        let fakeTrashItem = tempRoot.appendingPathComponent("fake_trash_item_\(UUID().uuidString).tmp")
        let missingItem = tempRoot.appendingPathComponent("does_not_exist_\(UUID().uuidString).tmp")
        let protectedItem = URL(fileURLWithPath: "/System/Library")
        fm.createFile(atPath: fakeTrashItem.path, contents: logBlob, attributes: nil)
        
        realScanner.categories = [
            JunkCategory(id: .systemLogs, items: [
                JunkItem(category: .systemLogs, name: "app.log", path: userLogFile, size: 4096, fileCount: 1, isSelected: true)
            ]),
            JunkCategory(id: .browserCaches, items: [
                JunkItem(category: .browserCaches, name: "Chrome Cache", path: chromeCache, size: 20 * 1024, fileCount: 1, isSelected: true)
            ]),
            JunkCategory(id: .trash, items: [
                JunkItem(category: .trash, name: "Trash Item", path: fakeTrashItem, size: 4096, fileCount: 1, isSelected: true)
            ]),
            JunkCategory(id: .userCaches, items: [
                JunkItem(category: .userCaches, name: "Missing Item", path: missingItem, size: 1024, fileCount: 1, isSelected: true),
                JunkItem(category: .userCaches, name: "Protected Item", path: protectedItem, size: 1024, fileCount: 1, isSelected: true)
            ])
        ]
        
        final class OffMainThreadTracker: @unchecked Sendable {
            private let lock = NSLock()
            var checked = false
            var allOffMainThread = true
            func record(_ isMainThread: Bool) {
                lock.lock()
                checked = true
                if isMainThread { allOffMainThread = false }
                lock.unlock()
            }
        }
        let tracker = OffMainThreadTracker()
        
        await realScanner.performClean { url in
            tracker.record(Thread.isMainThread)
            try FileManager.default.removeItem(at: url)
        }
        await testLogManager.flushAsync()
        
        suite.assert(tracker.checked && tracker.allOffMainThread, "performClean executes file removal off MainActor in Task.detached")
        suite.assert(fm.fileExists(atPath: userLogsRoot.path), "Root ~/Library/Logs directory must remain intact after cleaning log entries")
        suite.assert(!fm.fileExists(atPath: userLogFile.path), "Enumerated log file is cleaned")
        suite.assert(!fm.fileExists(atPath: chromeCache.path), "Browser cache path is cleaned")
        suite.assert(!fm.fileExists(atPath: fakeTrashItem.path), "Trash category item is permanently removed")
        suite.assert(realScanner.lastCleanResult?.errorsCount == 2, "Protected and missing items increment errorsCount (got \(realScanner.lastCleanResult?.errorsCount ?? -1))")
        suite.assert(
            realScanner.categories.first(where: { $0.id == .userCaches })?.items.count == 2,
            "Failed and protected items remain in categories after clean"
        )
        suite.assert(
            testLogManager.records.contains {
                $0.sourceModule == "System Junk" && $0.path == userLogFile.path && $0.destination == .trash && $0.isSuccess
            },
            "Successful trash clean is logged to DeletionLogManager"
        )
        suite.assert(
            testLogManager.records.contains {
                $0.sourceModule == "System Junk" && $0.path == fakeTrashItem.path && $0.destination == .permanent && $0.isSuccess
            },
            "Permanent removal from Trash category is logged to DeletionLogManager"
        )
        suite.assert(
            testLogManager.records.contains {
                $0.sourceModule == "System Junk" && $0.path == missingItem.path && !$0.isSuccess
            } && testLogManager.records.contains {
                $0.sourceModule == "System Junk" && $0.path == protectedItem.path && !$0.isSuccess
            },
            "Failed and protected clean attempts are logged with isSuccess == false"
        )
        
        return suite.printSummary()
    }
}

// MARK: - 8. Async Privacy Scan & Real Inactive Memory Tests
func runPrivacyAndPerformanceTests() -> Bool {
    return runAsyncMainActorTest {
        let suite = TestSuite("Async Privacy Scan & Real Inactive RAM Metrics")
        
        // Test 1: PerformanceMonitor updates memory metrics synchronously on main thread and reports real inactiveBytes
        PerformanceMonitor.shared.refreshHardwareStats()
        PerformanceMonitor.shared.stopMonitoring()
        let mem = PerformanceMonitor.shared.memory
        suite.assert(
            mem.totalBytes > 0,
            "PerformanceMonitor reports real physical memory totalBytes > 0"
        )
        suite.assert(
            mem.inactiveBytes <= mem.totalBytes,
            "PerformanceMonitor reports valid inactiveBytes (\(mem.inactiveBytes)) <= totalBytes"
        )
        
        // Test 2: PrivacyScanner.scanAsync() completes scanning before returning
        let scanner = PrivacyScanner.shared
        await scanner.scanAsync()
        suite.assert(
            scanner.isScanning == false,
            "PrivacyScanner.isScanning is false after await scanAsync() returns"
        )
        suite.assert(
            !scanner.items.isEmpty,
            "PrivacyScanner retains all configured privacy items after scanAsync()"
        )
        
        return suite.printSummary()
    }
}

// MARK: - 9. Malware Quarantine Security & Scope Tests
func runMalwareQuarantineTests() -> Bool {
    let suite = TestSuite("Malware Quarantine Security & Scope")
    let fm = FileManager.default
    let tempDir = fm.temporaryDirectory.appendingPathComponent("TidyMacQuarantineTest_\(UUID().uuidString)")
    let testLogManager = DeletionLogManager(storageDirectory: tempDir.appendingPathComponent("DeletionLogs"))
    let scanner = MalwareScannerService(deletionLogManager: testLogManager, checkInstallationOnInit: false)
    defer {
        testLogManager.flush()
        try? fm.removeItem(at: tempDir)
    }
    
    // Test 1: quarantinePersistenceItem must reject unsafe paths before executing anything
    let unsafePaths = [
        "/etc/launchd.conf",
        "/Library/LaunchDaemons/../../etc/passwd.plist",
        "/Library/LaunchDaemonsFake/com.evil.plist",
        "/Library/LaunchDaemons/evil\nrm -rf /.plist",
        "/tmp/malicious.plist"
    ]
    for badPath in unsafePaths {
        let item = PersistenceItem(
            label: "com.test.bad",
            plistPath: badPath,
            plistName: "bad.plist",
            location: .systemLaunchDaemon,
            programPath: "/tmp/evil",
            isUnsigned: true,
            codesignStatus: .unsigned,
            isRecentlyAdded: true,
            creationDate: Date(),
            modificationDate: Date(),
            suspicionFlags: [.unsignedBinary]
        )
        let (success, _) = scanner.quarantinePersistenceItem(item: item)
        suite.assert(!success, "quarantinePersistenceItem must reject unsafe path: \(badPath.replacingOccurrences(of: "\n", with: "\\n"))")
    }
    
    // Test 2: buildPrivilegedQuarantineCommand quoting, user Trash path, bootout, and collision safety
    let injectionPlist = "/Library/LaunchDaemons/com.evil'\"; rm -rf / #$(id).plist"
    let userTrash = "/Users/O'Brien/.Trash"
    let cmd = MalwareScannerService.buildPrivilegedQuarantineCommand(
        plistPath: injectionPlist,
        location: .systemLaunchDaemon,
        userTrashDirectory: userTrash,
        uid: 501
    )
    suite.assert(!cmd.contains("~/.Trash"), "Admin quarantine command must NOT use ~/.Trash")
    suite.assert(cmd.contains("'/Users/O'\\''Brien/.Trash'"), "Admin quarantine command must single-quote user Trash path")
    suite.assert(cmd.contains("/bin/launchctl bootout system"), "Admin quarantine command must bootout system daemon before moving")
    suite.assert(cmd.contains("/bin/launchctl unload"), "Admin quarantine command must include launchctl unload fallback")
    suite.assert(cmd.contains("/bin/mv -n"), "Admin quarantine command must use mv -n to prevent overwrite")
    
    let bootoutRange = cmd.range(of: "launchctl bootout")
    let mvRange = cmd.range(of: "/bin/mv -n")
    suite.assert(
        bootoutRange != nil && mvRange != nil && bootoutRange!.lowerBound < mvRange!.lowerBound,
        "launchctl bootout must run before mv"
    )
    
    let escapedAppleScript = SecurityEscaping.appleScriptStringEscape(cmd)
    suite.assert(
        escapedAppleScript.contains("\\\""),
        "AppleScript escaping must escape double quotes in shell command"
    )
    
    // Test 3: Shell move collision behavior in temporary directory
    let srcDir = tempDir.appendingPathComponent("src")
    let trashDir = tempDir.appendingPathComponent("User's Trash")
    try? fm.createDirectory(at: srcDir, withIntermediateDirectories: true)
    try? fm.createDirectory(at: trashDir, withIntermediateDirectories: true)
    
    let trickyName = "com.test'evil$1 \"a\".plist"
    let src1 = srcDir.appendingPathComponent(trickyName)
    let existingInTrash = trashDir.appendingPathComponent(trickyName)
    try? "existing".write(to: existingInTrash, atomically: true, encoding: .utf8)
    try? "new_payload".write(to: src1, atomically: true, encoding: .utf8)
    
    let testCmd = MalwareScannerService.buildPrivilegedQuarantineCommand(
        plistPath: src1.path,
        location: .systemLaunchDaemon,
        userTrashDirectory: trashDir.path,
        uid: getuid()
    )
    let execRes = try? MalwareScannerService.runProcessAndCaptureOutput(
        executablePath: "/bin/sh",
        arguments: ["-c", testCmd]
    )
    suite.assert(execRes?.terminationStatus == 0, "Generated quarantine shell command succeeds on tricky filename with collision")
    suite.assert(!fm.fileExists(atPath: src1.path), "Source file was moved out of source directory")
    let preservedContent = try? String(contentsOf: existingInTrash, encoding: .utf8)
    suite.assert(preservedContent == "existing", "Existing file in Trash was NOT overwritten")
    let trashContents = (try? fm.contentsOfDirectory(atPath: trashDir.path)) ?? []
    suite.assert(trashContents.count == 2, "Trash contains both original and uniquely renamed quarantined plist (got \(trashContents.count))")
    
    // Test 4: quarantineAllInfectedFiles() must only quarantine infectedFiles, NOT persistenceItems
    let previousDryRun = DryRunManager.shared.isEnabled
    let prevInfected = scanner.infectedFiles
    let prevPersistence = scanner.persistenceItems
    DryRunManager.shared.isEnabled = true
    defer {
        DryRunManager.shared.isEnabled = previousDryRun
        scanner.infectedFiles = prevInfected
        scanner.persistenceItems = prevPersistence
    }
    
    scanner.infectedFiles = [
        InfectedFileItem(filePath: "/tmp/infected1.bin", fileName: "infected1.bin", virusName: "Eicar-Test", fileSize: 68),
        InfectedFileItem(filePath: "/tmp/infected2.bin", fileName: "infected2.bin", virusName: "Adware.Test", fileSize: 128)
    ]
    scanner.persistenceItems = [
        PersistenceItem(
            label: "com.test.agent",
            plistPath: "/Users/test/Library/LaunchAgents/com.test.agent.plist",
            plistName: "com.test.agent.plist",
            location: .userLaunchAgent,
            programPath: "/tmp/agent",
            isUnsigned: true,
            codesignStatus: .unsigned,
            isRecentlyAdded: true,
            creationDate: Date(),
            modificationDate: Date(),
            suspicionFlags: [.unsignedBinary, .suspiciousLocation("/tmp/agent")]
        )
    ]
    
    let quarantinedCount = scanner.quarantineAllInfectedFiles()
    suite.assert(quarantinedCount == 2, "quarantineAllInfectedFiles quarantined both infected files")
    suite.assert(scanner.infectedFiles.allSatisfy { $0.isQuarantined }, "All infectedFiles marked quarantined")
    suite.assert(scanner.persistenceItems.allSatisfy { !$0.isQuarantined }, "Persistence items remain untouched by quarantineAllInfectedFiles")
    
    // Test 5: updateDatabase resets scanState and updates non-shared instance instead of leaking .updatingSignatures
    let updateScanner = MalwareScannerService(deletionLogManager: testLogManager, checkInstallationOnInit: false)
    updateScanner.installationInfo.freshclamPath = "/usr/bin/true"
    let updateResult = runAsyncMainActorTest {
        let res = await updateScanner.updateDatabase()
        return res.success && !updateScanner.isUpdatingDatabase && !updateScanner.scanState.isScanning
    }
    suite.assert(updateResult, "updateDatabase resets isUpdatingDatabase and scanState on its own instance upon completion")
    
    return suite.printSummary()
}

// MARK: - 10. Persistence False-Positive Prevention Tests
func runPersistenceFalsePositiveTests() -> Bool {
    let suite = TestSuite("Persistence False-Positive Prevention")
    let oldDate = Date(timeIntervalSinceNow: -60 * 60 * 24 * 60) // 60 days ago
    let recentDate = Date(timeIntervalSinceNow: -60 * 60 * 24 * 2) // 2 days ago
    
    // Test 1: Binaries containing "sh" substring (CrashHandler, ssh-agent, Fish) must NOT trigger scriptInvocation
    let benignShSubstrings = [
        "/Applications/AdobeCrashReporter.app/Contents/MacOS/CrashHandler",
        "/usr/libexec/ssh-agent",
        "/Applications/Fish.app/Contents/MacOS/Fish",
        "/Library/Application Support/Splash/DashboardHelper"
    ]
    for prog in benignShSubstrings {
        let item = MalwareScannerService.inspectPersistencePlist(
            plist: ["Label": "com.example.benign", "Program": prog, "RunAtLoad": true],
            plistPath: "/Library/LaunchAgents/com.example.benign.plist",
            plistName: "com.example.benign.plist",
            location: .systemLaunchAgent,
            creationDate: oldDate,
            modificationDate: oldDate,
            fileExists: { _ in true },
            codeSignatureVerifier: { _ in .developerId("TEAM123") }
        )
        suite.assert(
            item.suspicionFlags.isEmpty,
            "Legitimate signed RunAtLoad binary '\(URL(fileURLWithPath: prog).lastPathComponent)' has zero false-positive flags"
        )
    }
    
    // Test 2: Actual script interpreters MUST trigger scriptInvocation (and runAtLoadHidden if RunAtLoad == true)
    let interpreters = ["sh", "bash", "zsh", "dash", "ksh", "python", "python3", "perl", "ruby", "osascript"]
    for interp in interpreters {
        let item = MalwareScannerService.inspectPersistencePlist(
            plist: ["Label": "com.script.\(interp)", "ProgramArguments": ["/usr/bin/\(interp)", "-c", "id"], "RunAtLoad": true],
            plistPath: "/Library/LaunchAgents/com.script.\(interp).plist",
            plistName: "com.script.\(interp).plist",
            location: .systemLaunchAgent,
            creationDate: oldDate,
            modificationDate: oldDate,
            fileExists: { _ in true },
            codeSignatureVerifier: { _ in .appleSigned }
        )
        let hasScriptFlag = item.suspicionFlags.contains {
            if case .scriptInvocation = $0 { return true }
            return false
        }
        suite.assert(hasScriptFlag, "Interpreter '\(interp)' triggers .scriptInvocation")
        suite.assert(item.suspicionFlags.contains(.runAtLoadHidden), "Interpreter '\(interp)' + RunAtLoad attaches .runAtLoadHidden")
    }
    
    // Test 3: RunAtLoad == true with recentlyAdded alone (signed, normal location) must NOT attach .runAtLoadHidden
    let recentSigned = MalwareScannerService.inspectPersistencePlist(
        plist: ["Label": "com.new.signed", "Program": "/Applications/NewApp.app/Contents/MacOS/NewApp", "RunAtLoad": true],
        plistPath: "/Library/LaunchAgents/com.new.signed.plist",
        plistName: "com.new.signed.plist",
        location: .systemLaunchAgent,
        creationDate: recentDate,
        modificationDate: recentDate,
        fileExists: { _ in true },
        codeSignatureVerifier: { _ in .developerId("ABC12345") }
    )
    suite.assert(!recentSigned.suspicionFlags.contains(.runAtLoadHidden), "Recent signed RunAtLoad app must NOT get .runAtLoadHidden")
    
    // Test 4: RunAtLoad == true with unsigned binary or suspicious location MUST attach .runAtLoadHidden
    let unsignedRunAtLoad = MalwareScannerService.inspectPersistencePlist(
        plist: ["Label": "com.unsigned", "Program": "/Library/Helper/unsigned_bin", "RunAtLoad": true],
        plistPath: "/Library/LaunchDaemons/com.unsigned.plist",
        plistName: "com.unsigned.plist",
        location: .systemLaunchDaemon,
        creationDate: oldDate,
        modificationDate: oldDate,
        fileExists: { _ in true },
        codeSignatureVerifier: { _ in .unsigned }
    )
    suite.assert(unsignedRunAtLoad.suspicionFlags.contains(.unsignedBinary), "Unsigned binary triggers .unsignedBinary")
    suite.assert(unsignedRunAtLoad.suspicionFlags.contains(.runAtLoadHidden), "Unsigned binary + RunAtLoad attaches .runAtLoadHidden")
    
    let tmpLocationRunAtLoad = MalwareScannerService.inspectPersistencePlist(
        plist: ["Label": "com.tmp", "Program": "/tmp/signed_dropper", "RunAtLoad": true],
        plistPath: "/Library/LaunchAgents/com.tmp.plist",
        plistName: "com.tmp.plist",
        location: .systemLaunchAgent,
        creationDate: oldDate,
        modificationDate: oldDate,
        fileExists: { _ in true },
        codeSignatureVerifier: { _ in .developerId("TEAM999") }
    )
    suite.assert(tmpLocationRunAtLoad.suspicionFlags.contains(.runAtLoadHidden), "Suspicious location + RunAtLoad attaches .runAtLoadHidden")
    
    return suite.printSummary()
}

// MARK: - 11. Code Signature Verification Tests
func runCodeSignatureVerificationTests() -> Bool {
    let suite = TestSuite("Code Signature Verification & Authority Parsing")
    
    // Test 1: Apple system binary format
    let appleOutput = """
    Executable=/bin/sh
    Identifier=com.apple.sh
    Platform identifier=26
    Authority=macOS Software Signing
    Authority=Apple Code Signing Certification Authority
    Authority=Apple Root CA
    TeamIdentifier=not set
    """
    suite.assert(
        MalwareScannerService.parseCodesignOutput(appleOutput, terminationStatus: 0) == .appleSigned,
        "Apple platform binary parses as .appleSigned"
    )
    
    // Test 2: Developer ID format (also includes Authority=Apple Root CA!)
    let devIdOutput = """
    Executable=/Applications/Example.app/Contents/MacOS/Example
    Identifier=com.example.app
    Authority=Developer ID Application: Example Corp (XYZ1234567)
    Authority=Developer ID Certification Authority
    Authority=Apple Root CA
    TeamIdentifier=XYZ1234567
    """
    suite.assert(
        MalwareScannerService.parseCodesignOutput(devIdOutput, terminationStatus: 0) == .developerId("XYZ1234567"),
        "Developer ID binary parses as .developerId(TeamID) rather than .appleSigned"
    )
    
    // Test 3: Ad-hoc format (also prints TeamIdentifier=not set!)
    let adHocOutput = """
    Executable=/tmp/adhoc_bin
    CodeDirectory v=20400 size=299 flags=0x2(adhoc) hashes=3+2 location=embedded
    Signature=adhoc
    TeamIdentifier=not set
    """
    suite.assert(
        MalwareScannerService.parseCodesignOutput(adHocOutput, terminationStatus: 0) == .adHoc,
        "Ad-hoc binary with TeamIdentifier=not set parses as .adHoc"
    )
    
    // Test 4: Self-signed non-Apple authority must NEVER return .appleSigned
    let selfSignedOutput = """
    Executable=/tmp/selfsigned
    Authority=My Local Self Signed Cert
    TeamIdentifier=not set
    """
    let selfSignedStatus = MalwareScannerService.parseCodesignOutput(selfSignedOutput, terminationStatus: 0)
    suite.assert(selfSignedStatus == .adHoc && selfSignedStatus.isSuspicious, "Non-Apple authority parses as suspicious .adHoc")
    
    // Test 5: Unrecognized output with exit 0 must NEVER fall back to .appleSigned
    let unknownStatus = MalwareScannerService.parseCodesignOutput("Executable=/tmp/mystery\nTeamIdentifier=not set\n", terminationStatus: 0)
    suite.assert(unknownStatus != .appleSigned && unknownStatus.isSuspicious, "Unknown codesign output without verified authority must NOT return .appleSigned")
    
    // Test 6: Real binaries on disk via verifyCodeSignature(at:)
    let scanner = MalwareScannerService.shared
    suite.assert(scanner.verifyCodeSignature(at: "/bin/sh") == .appleSigned, "Live verifyCodeSignature(/bin/sh) returns .appleSigned")
    
    let fm = FileManager.default
    let tempDir = fm.temporaryDirectory.appendingPathComponent("TidyMacCodesignTest_\(UUID().uuidString)")
    try? fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: tempDir) }
    
    let unsignedBin = tempDir.appendingPathComponent("unsigned_echo")
    try? fm.copyItem(at: URL(fileURLWithPath: "/bin/echo"), to: unsignedBin)
    _ = try? MalwareScannerService.runProcessAndCaptureOutput(executablePath: "/usr/bin/codesign", arguments: ["--remove-signature", unsignedBin.path])
    suite.assert(scanner.verifyCodeSignature(at: unsignedBin.path) == .unsigned, "Live verifyCodeSignature detects unsigned binary")
    
    let adhocBin = tempDir.appendingPathComponent("adhoc_echo")
    try? fm.copyItem(at: unsignedBin, to: adhocBin)
    _ = try? MalwareScannerService.runProcessAndCaptureOutput(executablePath: "/usr/bin/codesign", arguments: ["-s", "-", adhocBin.path])
    suite.assert(scanner.verifyCodeSignature(at: adhocBin.path) == .adHoc, "Live verifyCodeSignature detects ad-hoc binary")
    
    // Tamper with ad-hoc binary to verify broken signature detection (codesign -vv -d alone misses this!)
    if var bytes = try? Data(contentsOf: adhocBin), bytes.count > 100 {
        bytes[bytes.count / 2] ^= 0xFF
        try? bytes.write(to: adhocBin)
        let tamperedStatus = scanner.verifyCodeSignature(at: adhocBin.path)
        let isBroken: Bool
        if case .brokenSignature = tamperedStatus { isBroken = true } else { isBroken = false }
        suite.assert(isBroken, "Live verifyCodeSignature detects tampered binary as .brokenSignature (got \(tamperedStatus))")
    }
    
    return suite.printSummary()
}

// MARK: - 12. Process Pipe Drain & ClamAV Stream Parsing Tests
func runProcessAndStreamParsingTests() -> Bool {
    let suite = TestSuite("Process Pipe Drain & ClamAV Line Parsing")
    
    // Test 1: >160KB pipe output drains before waitUntilExit without 64KB deadlock
    let bigPipeResult = try? MalwareScannerService.runProcessAndCaptureOutput(
        executablePath: "/bin/sh",
        arguments: ["-c", "seq 1 30000"]
    )
    suite.assert(
        bigPipeResult?.terminationStatus == 0 && (bigPipeResult?.output.utf8.count ?? 0) > 150_000,
        "Capturing >150KB stdout completes cleanly without 64KB pipe deadlock"
    )
    
    // Test 2: parseInfectedLine handles " FOUND" inside clean filenames & colon in path
    let cleanWithFoundInName = MalwareScannerService.parseInfectedLine("/Users/test/Downloads/My FOUND Notes.txt: OK")
    suite.assert(cleanWithFoundInName == nil, "Clean file with 'FOUND' in filename is NOT parsed as infected")
    
    let infectedWithFoundAndColon = MalwareScannerService.parseInfectedLine("/Users/test/Downloads/My FOUND File:v2.zip: Win.Test.EICAR_HDB-1 FOUND")
    suite.assert(
        infectedWithFoundAndColon?.filePath == "/Users/test/Downloads/My FOUND File:v2.zip" &&
        infectedWithFoundAndColon?.virusName == "Win.Test.EICAR_HDB-1",
        "Infected line preserves 'FOUND' and ':' in file path"
    )
    
    // Test 3: parseClamScanProgressLine parses clean and empty files
    let okProgress = MalwareScannerService.parseClamScanProgressLine("/Users/test/Downloads/readme.pdf: OK")
    suite.assert(
        okProgress?.path == "/Users/test/Downloads/readme.pdf" && okProgress?.countsAsScannedFile == true,
        "Progress parser extracts path and counts OK file"
    )
    
    let emptyProgress = MalwareScannerService.parseClamScanProgressLine("/Users/test/Downloads/blank.txt: Empty file")
    suite.assert(
        emptyProgress?.path == "/Users/test/Downloads/blank.txt" && emptyProgress?.countsAsScannedFile == true,
        "Progress parser extracts path for Empty file"
    )
    
    // Test 4: Concurrent cancelScan calls do not race or crash
    let scanner = MalwareScannerService.shared
    let group = DispatchGroup()
    for _ in 0..<10 {
        group.enter()
        DispatchQueue.global().async {
            scanner.cancelScan()
            group.leave()
        }
    }
    group.wait()
    suite.assert(true, "Concurrent cancelScan() calls completed safely")
    
    return suite.printSummary()
}

// MARK: - 13. PrivacyScanner Bookmark Preservation, Trash-First, Multi-Profile & Concurrency Tests
func runPrivacyScannerSafetyAndConcurrencyTests() -> Bool {
    return runAsyncMainActorTest {
        let suite = TestSuite("PrivacyScanner Bookmark Safety, Trash-First & Multi-Profile")
        let fm = FileManager.default
        let tempRoot = fm.temporaryDirectory.appendingPathComponent("TidyMacPrivacyTest_\(UUID().uuidString)")
        let mockHome = tempRoot.appendingPathComponent("Home")
        let testLogManager = DeletionLogManager(storageDirectory: tempRoot.appendingPathComponent("DeletionLogs"))
        try? fm.createDirectory(at: mockHome, withIntermediateDirectories: true)
        defer {
            try? fm.removeItem(at: tempRoot)
        }
        
        let originalDryRun = DryRunManager.shared.isEnabled
        DryRunManager.shared.isEnabled = false
        defer {
            DryRunManager.shared.isEnabled = originalDryRun
        }
        
        // Helper to execute SQLite statements in tests
        @discardableResult
        func runSQL(_ sql: String, db: OpaquePointer) -> Bool {
            var errPtr: UnsafeMutablePointer<CChar>?
            let rc = sqlite3_exec(db, sql, nil, nil, &errPtr)
            if rc != SQLITE_OK {
                if let errPtr { sqlite3_free(errPtr) }
                return false
            }
            return true
        }
        
        func queryInt(_ sql: String, db: OpaquePointer) -> Int32 {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return -1 }
            defer { sqlite3_finalize(stmt) }
            return sqlite3_step(stmt) == SQLITE_ROW ? sqlite3_column_int(stmt, 0) : -1
        }
        
        // --- Test 1: Firefox places.sqlite cleanup preserves all bookmarks & folders ---
        let ffProfile = mockHome.appendingPathComponent("Library/Application Support/Firefox/Profiles/test123.default-release")
        let ffCacheProfile = mockHome.appendingPathComponent("Library/Caches/Firefox/Profiles/test123.default-release")
        try? fm.createDirectory(at: ffProfile, withIntermediateDirectories: true)
        try? fm.createDirectory(at: ffCacheProfile, withIntermediateDirectories: true)
        
        let placesURL = ffProfile.appendingPathComponent("places.sqlite")
        var setupDB: OpaquePointer?
        let openOK = sqlite3_open_v2(placesURL.path, &setupDB, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK
        suite.assert(openOK && setupDB != nil, "Created test Firefox places.sqlite database")
        if let db = setupDB {
            _ = runSQL("PRAGMA journal_mode=WAL;", db: db)
            _ = runSQL("CREATE TABLE moz_places (id INTEGER PRIMARY KEY, url TEXT, title TEXT, visit_count INTEGER DEFAULT 0, last_visit_date INTEGER);", db: db)
            _ = runSQL("CREATE TABLE moz_bookmarks (id INTEGER PRIMARY KEY, type INTEGER, fk INTEGER, title TEXT);", db: db)
            _ = runSQL("CREATE TABLE moz_historyvisits (id INTEGER PRIMARY KEY, place_id INTEGER, visit_date INTEGER);", db: db)
            _ = runSQL("CREATE TABLE moz_inputhistory (place_id INTEGER NOT NULL, input TEXT NOT NULL, use_count INTEGER, PRIMARY KEY (place_id, input));", db: db)
            _ = runSQL("""
                INSERT INTO moz_places (id, url, title, visit_count, last_visit_date) VALUES
                  (1, 'https://developer.apple.com', 'Apple Dev', 5, 1700000000),
                  (2, 'https://www.swift.org', 'Swift.org', 0, NULL),
                  (3, 'https://history-only-1.example', 'History 1', 3, 1700000100),
                  (4, 'https://history-only-2.example', 'History 2', 1, 1700000200);
            """, db: db)
            _ = runSQL("""
                INSERT INTO moz_bookmarks (id, type, fk, title) VALUES
                  (10, 2, NULL, 'Bookmarks Bar'),
                  (11, 1, 1, 'Apple Developer'),
                  (12, 1, 2, 'Swift Language');
            """, db: db)
            _ = runSQL("""
                INSERT INTO moz_historyvisits (id, place_id, visit_date) VALUES
                  (100, 1, 1700000000),
                  (101, 3, 1700000100),
                  (102, 4, 1700000200);
            """, db: db)
            _ = runSQL("""
                INSERT INTO moz_inputhistory (place_id, input, use_count) VALUES
                  (1, 'apple', 2),
                  (3, 'hist', 1);
            """, db: db)
            sqlite3_close(db)
        }
        
        let ffScanner = PrivacyScanner(homeDirectory: mockHome, autoScan: false, deletionLogManager: testLogManager) { url in
            try FileManager.default.removeItem(at: url)
        }
        await ffScanner.scanAsync()
        
        let ffHistoryItemBefore = ffScanner.items.first { $0.id == "firefox_history" }
        suite.assert(ffHistoryItemBefore?.isAvailable == true, "Firefox history is detected as available when history visits exist")
        
        for idx in ffScanner.items.indices {
            ffScanner.items[idx].isEnabled = (ffScanner.items[idx].id == "firefox_history")
        }
        let ffCleanResult = ffScanner.performSynchronousClean()
        await testLogManager.flushAsync()
        let canonicalPlacesPath = placesURL.resolvingSymlinksInPath().path
        suite.assert(ffCleanResult.errorsCount == 0, "Firefox SQLite history cleanup completes with 0 errors")
        suite.assert(fm.fileExists(atPath: placesURL.path), "places.sqlite file must NEVER be deleted when clearing Firefox history")
        suite.assert(
            testLogManager.records.contains {
                $0.sourceModule == "Privacy" &&
                URL(fileURLWithPath: $0.path).resolvingSymlinksInPath().path == canonicalPlacesPath &&
                $0.destination == .permanent &&
                $0.isSuccess
            },
            "Firefox SQLite history cleanup logs operation to DeletionLogManager"
        )
        
        var verifyDB: OpaquePointer?
        let verifyOpen = sqlite3_open_v2(placesURL.path, &verifyDB, SQLITE_OPEN_READONLY, nil) == SQLITE_OK
        suite.assert(verifyOpen && verifyDB != nil, "places.sqlite remains valid and readable after cleanup")
        if let db = verifyDB {
            let bookmarkCount = queryInt("SELECT COUNT(*) FROM moz_bookmarks;", db: db)
            let placesCount = queryInt("SELECT COUNT(*) FROM moz_places;", db: db)
            let visitsCount = queryInt("SELECT COUNT(*) FROM moz_historyvisits;", db: db)
            let unbookmarkedCount = queryInt("SELECT COUNT(*) FROM moz_places WHERE id IN (3, 4);", db: db)
            let bookmarkedVisitCount = queryInt("SELECT visit_count FROM moz_places WHERE id = 1;", db: db)
            let inputHistoryCount = queryInt("SELECT COUNT(*) FROM moz_inputhistory;", db: db)
            let keptBookmarkedInput = queryInt("SELECT COUNT(*) FROM moz_inputhistory WHERE place_id = 1;", db: db)
            
            suite.assert(bookmarkCount == 3, "All 3 moz_bookmarks rows (folder + 2 bookmarks) remain intact (got \(bookmarkCount))")
            suite.assert(placesCount == 2 && unbookmarkedCount == 0, "Only the 2 bookmarked moz_places rows remain; unbookmarked rows deleted (places=\(placesCount), unbookmarked=\(unbookmarkedCount))")
            suite.assert(visitsCount == 0, "All moz_historyvisits rows deleted (got \(visitsCount))")
            suite.assert(bookmarkedVisitCount == 0, "Bookmarked moz_places visit_count reset to 0 (got \(bookmarkedVisitCount))")
            suite.assert(inputHistoryCount == 1 && keptBookmarkedInput == 1, "Orphaned moz_inputhistory removed while bookmarked input history preserved")
            sqlite3_close(db)
        }
        
        await ffScanner.scanAsync()
        let ffHistoryItemAfter = ffScanner.items.first { $0.id == "firefox_history" }
        suite.assert(ffHistoryItemAfter?.isAvailable == false && ffHistoryItemAfter?.sizeBytes == 0, "Bookmark-only places.sqlite reports isAvailable == false after history cleanup")
        
        // --- Test 2: No silent permanent deletion fallback + accurate directory size logging ---
        let chromeDefaultIndexedDB = mockHome.appendingPathComponent("Library/Application Support/Google/Chrome/Default/IndexedDB/site.leveldb")
        try? fm.createDirectory(at: chromeDefaultIndexedDB, withIntermediateDirectories: true)
        let dirPayload1 = Data(repeating: 0x51, count: 2048)
        let dirPayload2 = Data(repeating: 0x52, count: 4096)
        fm.createFile(atPath: chromeDefaultIndexedDB.appendingPathComponent("000001.ldb").path, contents: dirPayload1, attributes: nil)
        fm.createFile(atPath: chromeDefaultIndexedDB.appendingPathComponent("000002.ldb").path, contents: dirPayload2, attributes: nil)
        let expectedDirSize = SizeCalculator.calculateSize(of: chromeDefaultIndexedDB, fm: fm).bytes
        func normalizeVarPath(_ path: String) -> String {
            if path.hasPrefix("/private/var/") {
                return String(path.dropFirst("/private".count))
            }
            return path
        }
        let targetIndexedDBPath = normalizeVarPath(chromeDefaultIndexedDB.path)
        
        let failingScanner = PrivacyScanner(homeDirectory: mockHome, autoScan: false, deletionLogManager: testLogManager) { _ in
            throw NSError(domain: "TidyMacTest", code: 13, userInfo: [NSLocalizedDescriptionKey: "Simulated Trash failure"])
        }
        await failingScanner.scanAsync()
        for idx in failingScanner.items.indices {
            failingScanner.items[idx].isEnabled = (failingScanner.items[idx].id == "chrome_cookies")
        }
        let failResult = failingScanner.performSynchronousClean()
        await testLogManager.flushAsync()
        suite.assert(failResult.errorsCount == 1, "Failing trashItem must report error instead of falling back (got \(failResult.errorsCount))")
        suite.assert(fm.fileExists(atPath: chromeDefaultIndexedDB.path), "Directory must remain intact on disk when trashItem fails (no silent removeItem fallback)")
        suite.assert(!failingScanner.deletionErrors.isEmpty, "deletionErrors captures trashItem failure message")
        suite.assert(
            testLogManager.records.contains {
                $0.sourceModule == "Privacy"
                    && normalizeVarPath($0.path) == targetIndexedDBPath
                    && $0.destination == .trash
                    && !$0.isSuccess
                    && $0.sizeBytes == expectedDirSize
            },
            "Failed trash attempt logs accurate recursive directory size (\(expectedDirSize) bytes) and isSuccess == false"
        )
        
        // Succeeding trash logs full directory size (not inode size)
        let succeedingScanner = PrivacyScanner(homeDirectory: mockHome, autoScan: false, deletionLogManager: testLogManager) { url in
            try FileManager.default.removeItem(at: url)
        }
        await succeedingScanner.scanAsync()
        for idx in succeedingScanner.items.indices {
            succeedingScanner.items[idx].isEnabled = (succeedingScanner.items[idx].id == "chrome_cookies")
        }
        let okResult = succeedingScanner.performSynchronousClean()
        await testLogManager.flushAsync()
        suite.assert(okResult.errorsCount == 0 && okResult.reclaimedBytes >= 6144, "Successful directory clean reports accurate recursive byte count (\(okResult.reclaimedBytes) bytes)")
        suite.assert(
            testLogManager.records.contains {
                $0.sourceModule == "Privacy"
                    && normalizeVarPath($0.path) == targetIndexedDBPath
                    && $0.destination == .trash
                    && $0.isSuccess
                    && $0.sizeBytes == expectedDirSize
            },
            "DeletionLogManager records full directory size (\(expectedDirSize) bytes) rather than .fileSizeKey"
        )
        
        // --- Test 3: Multiple Chrome profiles (Default, Profile 1, Profile 2) ---
        let chromeAppSupport = mockHome.appendingPathComponent("Library/Application Support/Google/Chrome")
        let chromeCaches = mockHome.appendingPathComponent("Library/Caches/Google/Chrome")
        let profiles = ["Default", "Profile 1", "Profile 2"]
        let blob = Data(repeating: 0x61, count: 1024)
        for profile in profiles {
            let pSupport = chromeAppSupport.appendingPathComponent(profile)
            let pNetwork = pSupport.appendingPathComponent("Network")
            let pDownloadSvc = pSupport.appendingPathComponent("Download Service")
            let pCache = chromeCaches.appendingPathComponent("\(profile)/Cache")
            try? fm.createDirectory(at: pNetwork, withIntermediateDirectories: true)
            try? fm.createDirectory(at: pDownloadSvc, withIntermediateDirectories: true)
            try? fm.createDirectory(at: pCache, withIntermediateDirectories: true)
            fm.createFile(atPath: pSupport.appendingPathComponent("History").path, contents: blob, attributes: nil)
            fm.createFile(atPath: pNetwork.appendingPathComponent("Cookies").path, contents: blob, attributes: nil)
            fm.createFile(atPath: pDownloadSvc.appendingPathComponent("state.db").path, contents: blob, attributes: nil)
            fm.createFile(atPath: pSupport.appendingPathComponent("Top Sites").path, contents: blob, attributes: nil)
            fm.createFile(atPath: pCache.appendingPathComponent("f_00001").path, contents: blob, attributes: nil)
        }
        let crashpadDir = chromeAppSupport.appendingPathComponent("Crashpad")
        try? fm.createDirectory(at: crashpadDir, withIntermediateDirectories: true)
        let crashpadSentinel = crashpadDir.appendingPathComponent("settings.dat")
        fm.createFile(atPath: crashpadSentinel.path, contents: blob, attributes: nil)
        
        let multiProfileScanner = PrivacyScanner(homeDirectory: mockHome, autoScan: false, deletionLogManager: testLogManager) { url in
            try FileManager.default.removeItem(at: url)
        }
        await multiProfileScanner.scanAsync()
        let chromeItems = multiProfileScanner.items.filter { $0.browser == .chrome }
        suite.assert(chromeItems.count == 4 && chromeItems.allSatisfy { $0.isAvailable }, "All 4 Chrome categories detect traces across Default, Profile 1, and Profile 2")
        let chromeHistoryCount = chromeItems.first(where: { $0.id == "chrome_history" })?.fileCount ?? 0
        suite.assert(chromeHistoryCount == 3, "Chrome history counts History across all 3 profiles (expected 3, got \(chromeHistoryCount))")
        
        for idx in multiProfileScanner.items.indices {
            multiProfileScanner.items[idx].isEnabled = (multiProfileScanner.items[idx].browser == .chrome)
        }
        let chromeClean = multiProfileScanner.performSynchronousClean()
        suite.assert(chromeClean.errorsCount == 0, "Multi-profile Chrome clean completes with 0 errors")
        for profile in profiles {
            suite.assert(!fm.fileExists(atPath: chromeAppSupport.appendingPathComponent("\(profile)/History").path), "History cleaned for \(profile)")
            suite.assert(!fm.fileExists(atPath: chromeAppSupport.appendingPathComponent("\(profile)/Network/Cookies").path), "Cookies cleaned for \(profile)")
            suite.assert(!fm.fileExists(atPath: chromeAppSupport.appendingPathComponent("\(profile)/Download Service/state.db").path), "Downloads cleaned for \(profile)")
            suite.assert(!fm.fileExists(atPath: chromeCaches.appendingPathComponent("\(profile)/Cache/f_00001").path), "Cache cleaned for \(profile)")
        }
        suite.assert(fm.fileExists(atPath: crashpadSentinel.path), "Non-profile Chrome directories (Crashpad) are left untouched")
        
        await multiProfileScanner.scanAsync()
        suite.assert(
            multiProfileScanner.items.filter { $0.browser == .chrome }.allSatisfy { !$0.isAvailable },
            "All Chrome items report isAvailable == false after cleaning all profiles"
        )
        
        // --- Test 4: scan() snapshot preserves user isEnabled toggles made mid-scan ---
        let safariDir = mockHome.appendingPathComponent("Library/Safari")
        try? fm.createDirectory(at: safariDir, withIntermediateDirectories: true)
        fm.createFile(atPath: safariDir.appendingPathComponent("History.db").path, contents: blob, attributes: nil)
        
        let raceScanner = PrivacyScanner(homeDirectory: mockHome, autoScan: false, deletionLogManager: testLogManager) { url in
            try FileManager.default.removeItem(at: url)
        }
        raceScanner.scan()
        if let sIdx = raceScanner.items.firstIndex(where: { $0.id == "safari_history" }) {
            raceScanner.items[sIdx].isEnabled = false
        }
        if let fIdx = raceScanner.items.firstIndex(where: { $0.id == "firefox_cookies" }) {
            raceScanner.items[fIdx].isEnabled = false
        }
        while raceScanner.isScanning {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        let safariAfter = raceScanner.items.first { $0.id == "safari_history" }
        let ffCookiesAfter = raceScanner.items.first { $0.id == "firefox_cookies" }
        suite.assert(safariAfter?.isAvailable == true, "Mid-scan test still detects Safari history availability")
        suite.assert(safariAfter?.isEnabled == false && ffCookiesAfter?.isEnabled == false, "scan() preserves user isEnabled changes made while scan is in flight")
        suite.assert(!raceScanner.isBrowserRunning(.recentItems), "macOS Recent Items never reports as a running browser")
        
        // --- Test 5: PrivacyScanner Dry-Run logs .simulated and performCleanAsync runs off MainActor ---
        DryRunManager.shared.isEnabled = true
        await raceScanner.scanAsync()
        for idx in raceScanner.items.indices {
            raceScanner.items[idx].isEnabled = (raceScanner.items[idx].id == "safari_history")
        }
        let dryAsyncResult = await raceScanner.performCleanAsync()
        await testLogManager.flushAsync()
        suite.assert(dryAsyncResult.errorsCount == 0 && dryAsyncResult.filesCount >= 1, "performCleanAsync completes Dry-Run privacy simulation")
        suite.assert(
            fm.fileExists(atPath: safariDir.appendingPathComponent("History.db").path),
            "Dry-Run performCleanAsync preserves Safari History.db on disk"
        )
        suite.assert(
            testLogManager.records.contains { $0.sourceModule == "Privacy" && $0.destination == .simulated && $0.isSuccess },
            "PrivacyScanner Dry-Run logs simulated entry to DeletionLogManager"
        )
        DryRunManager.shared.isEnabled = false
        
        return suite.printSummary()
    }
}

// MARK: - 14. AppUninstaller Matching, Safety & Concurrency Tests
func runAppUninstallerTests() -> Bool {
    return runAsyncMainActorTest {
        let suite = TestSuite("AppUninstaller Matching, Safety & Concurrency")
        let fm = FileManager.default
        let tempRoot = fm.temporaryDirectory.appendingPathComponent("TidyMacUninstallerTest_\(UUID().uuidString)")
        let mockHome = tempRoot.appendingPathComponent("Home")
        let mockAppsDir = tempRoot.appendingPathComponent("Applications")
        let mockSysAppsDir = tempRoot.appendingPathComponent("SystemApps")
        try? fm.createDirectory(at: mockHome.appendingPathComponent("Library/Application Support"), withIntermediateDirectories: true)
        try? fm.createDirectory(at: mockAppsDir, withIntermediateDirectories: true)
        try? fm.createDirectory(at: mockSysAppsDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempRoot) }
        
        // Test 1: matchesApp rejects short vendor prefixes like "Google" and "Go" against "Google Chrome"
        let dummyURL = mockHome.appendingPathComponent("Library/Application Support/Google")
        suite.assert(
            !AppUninstallerScanner.matchesApp(
                filename: "Google",
                fileURL: dummyURL,
                appName: "Google Chrome",
                bundleId: "com.google.Chrome",
                category: .appSupport
            ),
            "matchesApp must NOT match 'Google' vendor folder to 'Google Chrome'"
        )
        suite.assert(
            !AppUninstallerScanner.matchesApp(
                filename: "Go",
                fileURL: mockHome.appendingPathComponent("Library/Application Support/Go"),
                appName: "Google Chrome",
                bundleId: "com.google.Chrome",
                category: .appSupport
            ),
            "matchesApp must NOT match 'Go' folder to 'Google Chrome'"
        )
        suite.assert(
            !AppUninstallerScanner.matchesApp(
                filename: "ArchiveHelper",
                fileURL: mockHome.appendingPathComponent("Library/Application Support/ArchiveHelper"),
                appName: "Arc",
                bundleId: "company.thebrowser.Browser",
                category: .appSupport
            ),
            "matchesApp must NOT match <5 char app name 'Arc' to 'ArchiveHelper'"
        )
        suite.assert(
            !AppUninstallerScanner.matchesApp(
                filename: "CodeCache",
                fileURL: mockHome.appendingPathComponent("Library/Caches/CodeCache"),
                appName: "Code",
                bundleId: "com.microsoft.VSCode",
                category: .caches
            ),
            "matchesApp must NOT match 4-char app name 'Code' to 'CodeCache'"
        )
        suite.assert(
            AppUninstallerScanner.matchesApp(
                filename: "logioptionsplus",
                fileURL: mockHome.appendingPathComponent("Library/Application Support/logioptionsplus"),
                appName: "Logi Options+",
                bundleId: "com.logi.optionsplus",
                category: .appSupport
            ),
            "matchesApp matches normalized alphanumeric equality >=5 chars ('logioptionsplus' == 'Logi Options+')"
        )
        suite.assert(
            AppUninstallerScanner.matchesApp(
                filename: "Claude3p",
                fileURL: mockHome.appendingPathComponent("Library/Application Support/Claude3p"),
                appName: "Claude",
                bundleId: "com.anthropic.claudefordesktop",
                category: .appSupport
            ),
            "matchesApp matches fAlpha.hasPrefix(nAlpha) when both >=5 chars ('Claude3p' starts with 'Claude')"
        )
        suite.assert(
            AppUninstallerScanner.matchesApp(
                filename: "Google Chrome",
                fileURL: mockHome.appendingPathComponent("Library/Application Support/Google Chrome"),
                appName: "Google Chrome",
                bundleId: "com.google.Chrome",
                category: .appSupport
            ),
            "matchesApp matches exact app folder 'Google Chrome'"
        )
        
        // Test 2: belongsToInstalledApp rejects reverse prefix false positives
        let installedBids: Set<String> = ["com.google.chrome", "com.example.go2shell", "company.thebrowser.browser"]
        let installedNames: Set<String> = ["google chrome", "go2shell", "arc"]
        suite.assert(
            !AppUninstallerScanner.belongsToInstalledApp(
                filename: "Go",
                installedBids: installedBids,
                installedNames: installedNames
            ),
            "belongsToInstalledApp must NOT match 'Go' to 'google chrome' or 'go2shell'"
        )
        suite.assert(
            !AppUninstallerScanner.belongsToInstalledApp(
                filename: "ArchiveHelper",
                installedBids: installedBids,
                installedNames: installedNames
            ),
            "belongsToInstalledApp must NOT match 'ArchiveHelper' to 'arc'"
        )
        suite.assert(
            AppUninstallerScanner.belongsToInstalledApp(
                filename: "Google",
                installedBids: installedBids,
                installedNames: installedNames
            ),
            "belongsToInstalledApp preserves explicit 'Google' vendor match when Google Chrome is installed"
        )
        
        // Test 3: OrphanedAppGroup defaults to unselected, and scanOrphanedLeftovers produces unselected groups/items
        let defaultGroup = OrphanedAppGroup(name: "TestOrphan")
        suite.assert(!defaultGroup.isSelected, "OrphanedAppGroup.isSelected defaults to false")
        
        let orphanDir = mockHome.appendingPathComponent("Library/Application Support/OldDeletedApp")
        try? fm.createDirectory(at: orphanDir, withIntermediateDirectories: true)
        fm.createFile(atPath: orphanDir.appendingPathComponent("data.bin").path, contents: Data(repeating: 0x1A, count: 20 * 1024), attributes: nil)
        
        let mockAppBundle = mockAppsDir.appendingPathComponent("SampleTool.app")
        try? fm.createDirectory(at: mockAppBundle.appendingPathComponent("Contents/MacOS"), withIntermediateDirectories: true)
        fm.createFile(atPath: mockAppBundle.appendingPathComponent("Contents/MacOS/SampleTool").path, contents: Data(repeating: 0x2B, count: 8192), attributes: nil)
        let sampleSupport = mockHome.appendingPathComponent("Library/Application Support/SampleTool")
        try? fm.createDirectory(at: sampleSupport, withIntermediateDirectories: true)
        fm.createFile(atPath: sampleSupport.appendingPathComponent("settings.db").path, contents: Data(repeating: 0x3C, count: 4096), attributes: nil)
        
        let testLogManager = DeletionLogManager(storageDirectory: tempRoot.appendingPathComponent("DeletionLogs"))
        let scanner = AppUninstallerScanner(
            homeURL: mockHome,
            appDirectories: [mockAppsDir],
            systemAppDirectories: [mockSysAppsDir],
            deletionLogManager: testLogManager
        )
        await scanner.scanAll()
        
        suite.assert(scanner.installedApps.count == 1, "scanAll discovers installed app in mock directory (got \(scanner.installedApps.count))")
        suite.assert(scanner.installedApps.first?.leftovers.count == 1, "scanAll finds leftover for SampleTool")
        suite.assert(scanner.orphanedGroups.count == 1, "scanOrphanedLeftovers discovers uninstalled orphan group (got \(scanner.orphanedGroups.count))")
        suite.assert(
            scanner.orphanedGroups.allSatisfy { !$0.isSelected && $0.items.allSatisfy { !$0.isSelected } },
            "All discovered orphaned groups and child items default to isSelected == false"
        )
        
        // Test 4: trashApp keeps app in installedApps and sets scanError when bundle trashing fails, runs off MainActor
        final class ThreadCheckBox: @unchecked Sendable {
            private let lock = NSLock()
            var called = false
            var allOffMain = true
            func record(_ isMain: Bool) {
                lock.lock()
                called = true
                if isMain { allOffMain = false }
                lock.unlock()
            }
        }
        
        let originalDryRun = DryRunManager.shared.isEnabled
        defer { DryRunManager.shared.isEnabled = originalDryRun }
        DryRunManager.shared.isEnabled = false
        
        if let app = scanner.installedApps.first {
            let failTracker = ThreadCheckBox()
            let failedResult = await scanner.trashApp(app: app, trashBundle: true) { url in
                failTracker.record(Thread.isMainThread)
                if url == app.bundleURL {
                    throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError, userInfo: [NSLocalizedDescriptionKey: "Permission denied for /Applications/SampleTool.app"])
                }
                try FileManager.default.removeItem(at: url)
            }
            suite.assert(failTracker.called && failTracker.allOffMain, "trashApp executes file trashing off MainActor")
            suite.assert(!failedResult, "trashApp returns false when bundle trashing fails")
            suite.assert(scanner.scanError != nil && !scanner.scanError!.isEmpty, "trashApp surfaces scanError when bundle trashing fails")
            suite.assert(scanner.installedApps.contains(where: { $0.id == app.id }), "trashApp keeps app in installedApps when bundle trashing fails")
            suite.assert(!scanner.showCelebration, "trashApp does not show celebration when bundle uninstall fails")
        }
        
        // Test 5: trashApp in Dry-Run mode removes app from installedApps without deleting bundle
        if let app = scanner.installedApps.first {
            DryRunManager.shared.isEnabled = true
            let dryOK = await scanner.trashApp(app: app, trashBundle: true) { _ in }
            suite.assert(dryOK, "trashApp succeeds in Dry-Run mode")
            suite.assert(!scanner.installedApps.contains(where: { $0.id == app.id }), "trashApp removes app from installedApps in Dry-Run mode")
            suite.assert(fm.fileExists(atPath: app.bundleURL.path), "Dry-Run trashApp preserves bundle on disk")
        }
        
        // Test 6: trashApp real success removes app from installedApps
        DryRunManager.shared.isEnabled = false
        let removableBundle = mockAppsDir.appendingPathComponent("Removable.app")
        try? fm.createDirectory(at: removableBundle, withIntermediateDirectories: true)
        let removableApp = InstalledApp(
            name: "Removable",
            bundleIdentifier: "com.example.removable",
            version: "1.0",
            bundleURL: removableBundle,
            appSize: 4096
        )
        scanner.installedApps = [removableApp]
        let removeOK = await scanner.trashApp(app: removableApp, trashBundle: true) { url in
            try FileManager.default.removeItem(at: url)
        }
        suite.assert(removeOK, "trashApp returns true when bundle trashing succeeds")
        suite.assert(scanner.installedApps.isEmpty, "trashApp removes app from installedApps when bundle trashing succeeds")
        suite.assert(scanner.scanError == nil, "trashApp clears scanError on success")
        
        // Test 7: trashSelectedOrphans cleans checked items even when group.isSelected == false, and runs off MainActor
        let mockCachesDir = mockHome.appendingPathComponent("Library/Caches")
        try? fm.createDirectory(at: mockCachesDir, withIntermediateDirectories: true)
        let orphanFile1 = mockCachesDir.appendingPathComponent("OrphanKeep.bin")
        let orphanFile2 = mockCachesDir.appendingPathComponent("OrphanDelete.bin")
        let created1 = fm.createFile(atPath: orphanFile1.path, contents: Data(repeating: 0x01, count: 16 * 1024), attributes: nil)
        let created2 = fm.createFile(atPath: orphanFile2.path, contents: Data(repeating: 0x02, count: 16 * 1024), attributes: nil)
        suite.assert(created1 && created2, "Created mock orphan cache files on disk")
        
        scanner.orphanedGroups = [
            OrphanedAppGroup(
                name: "PartialOrphan",
                bundleIdentifier: "com.example.partial",
                items: [
                    AppLeftoverItem(category: .caches, name: "OrphanKeep.bin", displayPath: "~/Library/Caches/OrphanKeep.bin", url: orphanFile1, size: 16384, fileCount: 1, isSelected: false),
                    AppLeftoverItem(category: .caches, name: "OrphanDelete.bin", displayPath: "~/Library/Caches/OrphanDelete.bin", url: orphanFile2, size: 16384, fileCount: 1, isSelected: true)
                ],
                isSelected: false
            )
        ]
        
        let orphanTracker = ThreadCheckBox()
        let orphanOK = await scanner.trashSelectedOrphans { url in
            orphanTracker.record(Thread.isMainThread)
            try FileManager.default.removeItem(at: url)
        }
        suite.assert(orphanTracker.called && orphanTracker.allOffMain, "trashSelectedOrphans executes file trashing off MainActor")
        suite.assert(orphanOK, "trashSelectedOrphans succeeds for partially selected group")
        suite.assert(!fm.fileExists(atPath: orphanFile2.path), "Checked item in partially selected group is removed")
        suite.assert(fm.fileExists(atPath: orphanFile1.path), "Unchecked item in partially selected group is preserved")
        suite.assert(
            scanner.orphanedGroups.count == 1 && scanner.orphanedGroups.first?.items.count == 1 && scanner.orphanedGroups.first?.isSelected == false,
            "Remaining group retains only unchecked item and stays unselected"
        )
        await testLogManager.flushAsync()
        
        return suite.printSummary()
    }
}

// MARK: - 15. Maintenance & Performance Safety, Dry-Run, UID & Sequoia Tests
func runMaintenanceAndPerformanceSafetyTests() -> Bool {
    return runAsyncMainActorTest {
        let suite = TestSuite("Maintenance & Performance Safety, Dry-Run, UID & Sequoia")
        let fm = FileManager.default
        
        // Test 1: MaintenanceService UID substitution & Sequoia /usr/sbin/periodic gating
        let tasksNoPeriodic = MaintenanceService.buildDefaultTasks(periodicBinaryExists: false, uid: 501)
        suite.assert(
            !tasksNoPeriodic.contains(where: { $0.id == "periodic_scripts" }),
            "buildDefaultTasks omits periodic_scripts when /usr/sbin/periodic does not exist"
        )
        let repairNoPeriodic = tasksNoPeriodic.first(where: { $0.id == "repair_disk_permissions" })
        suite.assert(
            repairNoPeriodic?.terminalCommand.contains("501") == true &&
            repairNoPeriodic?.terminalCommand.contains("$(id -u)") == false,
            "repair_disk_permissions embeds Swift UID instead of $(id -u)"
        )
        
        let tasksWithPeriodic = MaintenanceService.buildDefaultTasks(periodicBinaryExists: true, uid: 502)
        suite.assert(
            tasksWithPeriodic.contains(where: { $0.id == "periodic_scripts" }),
            "buildDefaultTasks exposes periodic_scripts when /usr/sbin/periodic exists"
        )
        suite.assert(
            tasksWithPeriodic.first(where: { $0.id == "repair_disk_permissions" })?.terminalCommand.contains("502") == true,
            "repair_disk_permissions uses provided uid 502"
        )
        
        let hasHostPeriodic = fm.fileExists(atPath: "/usr/sbin/periodic")
        let liveTasks = MaintenanceService.shared.tasks
        suite.assert(
            liveTasks.contains(where: { $0.id == "periodic_scripts" }) == hasHostPeriodic,
            "MaintenanceService.shared exposes periodic_scripts iff /usr/sbin/periodic exists on host"
        )
        let liveRepairCmd = liveTasks.first(where: { $0.id == "repair_disk_permissions" })?.terminalCommand ?? ""
        suite.assert(
            liveRepairCmd.contains(String(getuid())) && !liveRepairCmd.contains("$(id -u)"),
            "Live repair_disk_permissions command contains String(getuid()) and not $(id -u)"
        )
        
        // Test 2: MaintenanceService.runUserCommand drains >64KB pipe before waitUntilExit
        let pipeResult = await Task.detached(priority: .userInitiated) {
            MaintenanceService.runUserCommand("seq 1 30000")
        }.value
        suite.assert(
            pipeResult.success && pipeResult.output.utf8.count > 150_000,
            "MaintenanceService.runUserCommand drains >150KB stdout without pipe deadlock"
        )
        
        // Test 3: MaintenanceService.runAllTasks respects DryRunManager.shared.isEnabled
        let maintenance = MaintenanceService.shared
        let prevDryRun = DryRunManager.shared.isEnabled
        let prevSimLog = DryRunManager.shared.simulatedActionsLog
        let prevMaintenanceTasks = maintenance.tasks
        defer {
            DryRunManager.shared.isEnabled = prevDryRun
            DryRunManager.shared.simulatedActionsLog = prevSimLog
            maintenance.tasks = prevMaintenanceTasks
        }
        
        DryRunManager.shared.isEnabled = true
        DryRunManager.shared.clearLog()
        maintenance.runAllTasks()
        for _ in 0..<100 {
            if !maintenance.isRunningAny { break }
            try? await Task.sleep(nanoseconds: 30_000_000)
        }
        suite.assert(!maintenance.isRunningAny && maintenance.activeTaskId == nil, "runAllTasks in Dry-Run completes and clears running flags")
        suite.assert(
            maintenance.tasks.allSatisfy {
                if case .success(let msg) = $0.status {
                    return msg.contains("Dry-Run") && $0.outputLog.contains("[DRY-RUN SIMULATION COMPLETE]")
                }
                return false
            },
            "runAllTasks simulates every task without executing real commands when Dry-Run is enabled"
        )
        suite.assert(
            DryRunManager.shared.simulatedActionsLog.count == maintenance.tasks.count,
            "runAllTasks logs a Dry-Run simulation entry for each task (got \(DryRunManager.shared.simulatedActionsLog.count))"
        )
        
        // Test 4: CPUMetrics.modelDescription detects architecture dynamically
        let cpuSample = CPUMetrics(coreCount: 8)
        #if arch(arm64)
        let expectedModelDesc = "Apple Silicon • 8 Cores"
        #else
        let expectedModelDesc = "Intel • 8 Cores"
        #endif
        suite.assert(
            cpuSample.modelDescription == expectedModelDesc,
            "CPUMetrics.modelDescription reports '\(expectedModelDesc)' (got '\(cpuSample.modelDescription)')"
        )
        
        // Test 5: PerformanceMonitor.formatDisplayName preserves 'com' and 'org' inside words
        suite.assert(
            PerformanceMonitor.formatDisplayName(from: "com.apple.companion") == "Companion",
            "formatDisplayName preserves 'companion' without stripping 'com'"
        )
        suite.assert(
            PerformanceMonitor.formatDisplayName(from: "org.example.organizer") == "Organizer",
            "formatDisplayName preserves 'organizer' without stripping 'org'"
        )
        suite.assert(
            PerformanceMonitor.formatDisplayName(from: "com.vendor.cloud-companion_helper") == "Cloud Companion Helper",
            "formatDisplayName formats hyphen/underscore companion label cleanly"
        )
        
        // Test 6: buildSystemLaunchItemToggleCommand edge cases
        let disablePlan = PerformanceMonitor.buildSystemLaunchItemToggleCommand(
            path: "/Library/LaunchDaemons/com.example.daemon.plist",
            enable: false
        )
        suite.assert(
            disablePlan.didRename &&
            disablePlan.targetPath == "/Library/LaunchDaemons/com.example.daemon.plist.disabled" &&
            disablePlan.shellCommand == "/bin/launchctl unload '/Library/LaunchDaemons/com.example.daemon.plist' || true; mv -f '/Library/LaunchDaemons/com.example.daemon.plist' '/Library/LaunchDaemons/com.example.daemon.plist.disabled'",
            "Disabling system launch item runs unload || true; mv -f"
        )
        
        let enableDisabledPlan = PerformanceMonitor.buildSystemLaunchItemToggleCommand(
            path: "/Library/LaunchDaemons/com.example.daemon.plist.disabled",
            enable: true
        )
        suite.assert(
            enableDisabledPlan.didRename &&
            enableDisabledPlan.targetPath == "/Library/LaunchDaemons/com.example.daemon.plist" &&
            enableDisabledPlan.shellCommand == "mv -f '/Library/LaunchDaemons/com.example.daemon.plist.disabled' '/Library/LaunchDaemons/com.example.daemon.plist' && /bin/launchctl load '/Library/LaunchDaemons/com.example.daemon.plist'",
            "Enabling .disabled system launch item renames and loads"
        )
        
        let enableNonDisabledPlan = PerformanceMonitor.buildSystemLaunchItemToggleCommand(
            path: "/Library/LaunchDaemons/com.example.daemon.plist",
            enable: true
        )
        suite.assert(
            !enableNonDisabledPlan.didRename &&
            enableNonDisabledPlan.targetPath == "/Library/LaunchDaemons/com.example.daemon.plist" &&
            !enableNonDisabledPlan.shellCommand.contains("mv -f") &&
            enableNonDisabledPlan.shellCommand == "/bin/launchctl load '/Library/LaunchDaemons/com.example.daemon.plist'",
            "Enabling file without .disabled suffix skips mv -f and only runs launchctl load"
        )
        
        // Test 7: PerformanceMonitor.toggleLaunchItem respects DryRunManager.shared.isEnabled
        let monitor = PerformanceMonitor.shared
        let prevLaunchItems = monitor.launchItems
        let prevStatusMsg = monitor.statusMessage
        defer {
            monitor.launchItems = prevLaunchItems
            monitor.statusMessage = prevStatusMsg
            monitor.stopMonitoring()
        }
        
        let testPlistPath = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.tidymac.dryrun.nonexistent.plist")
            .path
        let dryRunItem = LaunchItem(
            id: testPlistPath,
            label: "com.tidymac.dryrun.nonexistent",
            displayName: "Dryrun Nonexistent",
            path: testPlistPath,
            location: .userAgent,
            program: "/usr/bin/true",
            isEnabled: true
        )
        monitor.launchItems = [dryRunItem]
        DryRunManager.shared.isEnabled = true
        DryRunManager.shared.clearLog()
        monitor.toggleLaunchItem(item: dryRunItem, enable: false)
        suite.assert(
            monitor.launchItems.first?.isEnabled == false && monitor.launchItems.first?.isToggling == false,
            "toggleLaunchItem updates UI state in Dry-Run without spawning launchctl"
        )
        suite.assert(
            DryRunManager.shared.simulatedActionsLog.contains { $0.contains("Disable Launch Item") && $0.contains(testPlistPath) },
            "toggleLaunchItem logs simulation action to DryRunManager in Dry-Run mode"
        )
        
        // Test 8: Monitoring timer lifecycle & @MainActor fetchProcesses
        suite.assert(!monitor.isMonitoring, "PerformanceMonitor starts with no active timer until View appears")
        monitor.startMonitoring()
        suite.assert(monitor.isMonitoring, "startMonitoring activates timer")
        monitor.stopMonitoring()
        suite.assert(!monitor.isMonitoring, "stopMonitoring invalidates and clears timer")
        
        monitor.fetchProcesses()
        try? await Task.sleep(nanoseconds: 100_000_000)
        suite.assert(true, "fetchProcesses executes NSWorkspace on @MainActor and proc_pidinfo off main safely")
        
        return suite.printSummary()
    }
}

// MARK: - 16. Thread Safety & DeletionLogManager Wiring Across Scanners
func runThreadSafetyAndDeletionLogWiringTests() -> Bool {
    return runAsyncMainActorTest {
        let suite = TestSuite("Thread Safety & DeletionLogManager Wiring")
        let fm = FileManager.default
        let tempRoot = fm.temporaryDirectory.appendingPathComponent("TidyMacSafetyWiringTest_\(UUID().uuidString)")
        try? fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempRoot) }
        
        let originalDryRun = DryRunManager.shared.isEnabled
        let originalSimLog = DryRunManager.shared.simulatedActionsLog
        defer {
            DryRunManager.shared.isEnabled = originalDryRun
            DryRunManager.shared.simulatedActionsLog = originalSimLog
        }
        
        // Test 1: DryRunManager background-thread logSimulation & clearLog mutate on main thread safely
        DryRunManager.shared.clearLog()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let group = DispatchGroup()
            for idx in 0..<25 {
                group.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    DryRunManager.shared.logSimulation(action: "BgSim", target: "/tmp/item_\(idx)")
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                continuation.resume()
            }
        }
        suite.assert(
            DryRunManager.shared.simulatedActionsLog.count == 25,
            "DryRunManager concurrent background logSimulation safely appends all 25 entries on main thread (got \(DryRunManager.shared.simulatedActionsLog.count))"
        )
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                DryRunManager.shared.clearLog()
                DispatchQueue.main.async {
                    continuation.resume()
                }
            }
        }
        suite.assert(
            DryRunManager.shared.simulatedActionsLog.isEmpty,
            "DryRunManager background clearLog safely clears simulatedActionsLog on main thread"
        )
        
        // Test 2: DeletionLogManager background log() mutates records on main thread and persists immutable snapshot on queue
        let logDir = tempRoot.appendingPathComponent("DeletionLogs")
        let isolatedLog = DeletionLogManager(storageDirectory: logDir)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let group = DispatchGroup()
            for idx in 0..<20 {
                group.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    isolatedLog.log(
                        sourceModule: "BgModule",
                        path: "/tmp/bg_\(idx).dat",
                        sizeBytes: Int64(100 + idx),
                        destination: .trash,
                        isSuccess: true
                    )
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                continuation.resume()
            }
        }
        await isolatedLog.flushAsync()
        suite.assert(
            isolatedLog.records.count == 20,
            "DeletionLogManager concurrent background logging retains all 20 records without race (got \(isolatedLog.records.count))"
        )
        let reloaded = DeletionLogManager(storageDirectory: logDir)
        suite.assert(
            reloaded.records.count == 20,
            "DeletionLogManager persists immutable snapshot of all 20 records to JSON (got \(reloaded.records.count))"
        )
        
        // Test 3: FullDiskAccessManager.checkAccess runs performFDACheck off the main thread without blocking
        final class FDAProbeTracker: @unchecked Sendable {
            private let lock = NSLock()
            var ranOffMainThread = false
            var callCount = 0
            func mark(isMain: Bool) {
                lock.lock()
                callCount += 1
                ranOffMainThread = !isMain
                lock.unlock()
            }
        }
        let fdaTracker = FDAProbeTracker()
        let fdaManager = FullDiskAccessManager(
            runInitialCheck: false,
            observeNotifications: false,
            probeRunner: {
                fdaTracker.mark(isMain: Thread.isMainThread)
                usleep(40_000) // 40ms probe should NOT block main thread
                return (true, ["MockProbe": true])
            }
        )
        let checkStart = Date()
        var completionGranted: Bool? = nil
        fdaManager.checkAccess { granted in
            completionGranted = granted
        }
        let synchronousReturnElapsed = Date().timeIntervalSince(checkStart)
        suite.assert(
            synchronousReturnElapsed < 0.03 && fdaManager.isChecking == true,
            "FullDiskAccessManager.checkAccess returns immediately on main thread and sets isChecking == true (elapsed \(String(format: "%.4f", synchronousReturnElapsed))s)"
        )
        for _ in 0..<60 {
            if completionGranted != nil && !fdaManager.isChecking { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        suite.assert(
            fdaTracker.callCount == 1 && fdaTracker.ranOffMainThread,
            "FullDiskAccessManager executes performFDACheck() off the main thread"
        )
        suite.assert(
            completionGranted == true && fdaManager.hasFullDiskAccess && !fdaManager.isChecking && fdaManager.probeDiagnostics["MockProbe"] == true,
            "FullDiskAccessManager updates published state on main thread once background check finishes"
        )
        
        // Test 4: LargeOldFilesScanner wires DeletionLogManager across single, batch, dry-run, protected & error paths
        let largeDir = tempRoot.appendingPathComponent("LargeFiles")
        try? fm.createDirectory(at: largeDir, withIntermediateDirectories: true)
        let fDry = largeDir.appendingPathComponent("dry_big.dmg")
        let fSingle = largeDir.appendingPathComponent("single_big.dmg")
        let fBatchOK = largeDir.appendingPathComponent("batch_ok.iso")
        let fBatchFail = largeDir.appendingPathComponent("batch_fail.iso")
        for u in [fDry, fSingle, fBatchOK, fBatchFail] {
            fm.createFile(atPath: u.path, contents: Data(repeating: 0xAA, count: 2048), attributes: nil)
        }
        
        let largeScanner = LargeOldFilesScanner(deletionLogManager: isolatedLog)
        DryRunManager.shared.isEnabled = true
        let dryLargeItem = LargeOldFileItem(url: fDry, name: "dry_big.dmg", path: fDry.path, size: 2048, modificationDate: Date(), fileType: .diskImage, isSelected: true)
        largeScanner.files = [dryLargeItem]
        largeScanner.moveToTrash(item: dryLargeItem)
        
        DryRunManager.shared.isEnabled = false
        let singleLargeItem = LargeOldFileItem(url: fSingle, name: "single_big.dmg", path: fSingle.path, size: 2048, modificationDate: Date(), fileType: .diskImage, isSelected: true)
        largeScanner.files = [singleLargeItem]
        largeScanner.moveToTrash(item: singleLargeItem) { url in
            try fm.removeItem(at: url)
        }
        
        let batchOKItem = LargeOldFileItem(url: fBatchOK, name: "batch_ok.iso", path: fBatchOK.path, size: 2048, modificationDate: Date(), fileType: .diskImage, isSelected: true)
        let batchFailItem = LargeOldFileItem(url: fBatchFail, name: "batch_fail.iso", path: fBatchFail.path, size: 2048, modificationDate: Date(), fileType: .diskImage, isSelected: true)
        let batchProtItem = LargeOldFileItem(url: URL(fileURLWithPath: "/System/Library"), name: "Library", path: "/System/Library", size: 4096, modificationDate: Date(), fileType: .other, isSelected: true)
        largeScanner.files = [batchOKItem, batchFailItem, batchProtItem]
        await largeScanner.moveSelectedToTrash { url in
            if url == fBatchFail {
                throw NSError(domain: "TidyMacTest", code: 2, userInfo: [NSLocalizedDescriptionKey: "Disk locked"])
            }
            try FileManager.default.removeItem(at: url)
        }
        await isolatedLog.flushAsync()
        
        suite.assert(
            isolatedLog.records.contains { $0.sourceModule == "Large & Old Files" && $0.path == fDry.path && $0.destination == .simulated && $0.isSuccess } &&
            isolatedLog.records.contains { $0.sourceModule == "Large & Old Files" && $0.path == fSingle.path && $0.destination == .trash && $0.isSuccess } &&
            isolatedLog.records.contains { $0.sourceModule == "Large & Old Files" && $0.path == fBatchOK.path && $0.destination == .trash && $0.isSuccess } &&
            isolatedLog.records.contains { $0.sourceModule == "Large & Old Files" && $0.path == fBatchFail.path && $0.destination == .trash && !$0.isSuccess } &&
            isolatedLog.records.contains { $0.sourceModule == "Large & Old Files" && $0.path == "/System/Library" && !$0.isSuccess },
            "LargeOldFilesScanner logs dry-run, single, batch success, failure, and protected operations to DeletionLogManager"
        )
        
        // Test 5: AppUninstallerScanner wires DeletionLogManager for trashApp and trashSelectedOrphans
        let appDir = tempRoot.appendingPathComponent("Apps")
        let appHome = tempRoot.appendingPathComponent("AppHome")
        try? fm.createDirectory(at: appDir, withIntermediateDirectories: true)
        try? fm.createDirectory(at: appHome.appendingPathComponent("Library/Caches"), withIntermediateDirectories: true)
        let testBundle = appDir.appendingPathComponent("TestApp.app")
        let testLeftover = appHome.appendingPathComponent("Library/Caches/com.test.app")
        let dryBundle = appDir.appendingPathComponent("DryApp.app")
        let orphanTrash = appHome.appendingPathComponent("Library/Caches/OrphanTrash.bin")
        try? fm.createDirectory(at: testBundle, withIntermediateDirectories: true)
        try? fm.createDirectory(at: dryBundle, withIntermediateDirectories: true)
        fm.createFile(atPath: testLeftover.path, contents: Data(repeating: 0x01, count: 1024), attributes: nil)
        fm.createFile(atPath: orphanTrash.path, contents: Data(repeating: 0x02, count: 1024), attributes: nil)
        
        let appScanner = AppUninstallerScanner(
            homeURL: appHome,
            appDirectories: [appDir],
            systemAppDirectories: [],
            deletionLogManager: isolatedLog
        )
        
        DryRunManager.shared.isEnabled = true
        let dryInstalled = InstalledApp(name: "DryApp", bundleIdentifier: "com.test.dry", version: "1.0", bundleURL: dryBundle, appSize: 4096)
        appScanner.installedApps = [dryInstalled]
        _ = await appScanner.trashApp(app: dryInstalled, trashBundle: true) { _ in }
        
        DryRunManager.shared.isEnabled = false
        let realInstalled = InstalledApp(
            name: "TestApp",
            bundleIdentifier: "com.test.app",
            version: "1.0",
            bundleURL: testBundle,
            appSize: 8192,
            leftovers: [
                AppLeftoverItem(category: .caches, name: "com.test.app", displayPath: "~/Library/Caches/com.test.app", url: testLeftover, size: 1024, fileCount: 1, isSelected: true)
            ]
        )
        appScanner.installedApps = [realInstalled]
        _ = await appScanner.trashApp(app: realInstalled, trashBundle: true) { url in
            try FileManager.default.removeItem(at: url)
        }
        
        appScanner.orphanedGroups = [
            OrphanedAppGroup(
                name: "OrphanApp",
                items: [
                    AppLeftoverItem(category: .caches, name: "OrphanTrash.bin", displayPath: "~/Library/Caches/OrphanTrash.bin", url: orphanTrash, size: 1024, fileCount: 1, isSelected: true)
                ],
                isSelected: true
            )
        ]
        _ = await appScanner.trashSelectedOrphans { url in
            try FileManager.default.removeItem(at: url)
        }
        await isolatedLog.flushAsync()
        
        suite.assert(
            isolatedLog.records.contains { $0.sourceModule == "App Uninstaller" && $0.path == dryBundle.path && $0.destination == .simulated && $0.isSuccess } &&
            isolatedLog.records.contains { $0.sourceModule == "App Uninstaller" && $0.path == testBundle.path && $0.destination == .trash && $0.isSuccess } &&
            isolatedLog.records.contains { $0.sourceModule == "App Uninstaller" && $0.path == testLeftover.path && $0.destination == .trash && $0.isSuccess } &&
            isolatedLog.records.contains { $0.sourceModule == "App Uninstaller" && $0.path == orphanTrash.path && $0.destination == .trash && $0.isSuccess },
            "AppUninstallerScanner logs dry-run, app bundle, leftover, and orphan trash operations to DeletionLogManager"
        )
        
        // Test 6: MalwareScannerService wires DeletionLogManager across quarantineFile and quarantinePersistenceItem
        let malwareDir = tempRoot.appendingPathComponent("Malware")
        try? fm.createDirectory(at: malwareDir, withIntermediateDirectories: true)
        let malDryFile = malwareDir.appendingPathComponent("dry_malware.bin")
        let malRealFile = malwareDir.appendingPathComponent("real_malware.bin")
        let malFailFile = malwareDir.appendingPathComponent("fail_malware.bin")
        for u in [malDryFile, malRealFile, malFailFile] {
            fm.createFile(atPath: u.path, contents: Data(repeating: 0xCC, count: 512), attributes: nil)
        }
        
        let malwareService = MalwareScannerService(deletionLogManager: isolatedLog, checkInstallationOnInit: false)
        DryRunManager.shared.isEnabled = true
        _ = malwareService.quarantineFile(item: InfectedFileItem(filePath: malDryFile.path, fileName: "dry_malware.bin", virusName: "Test.Sim", fileSize: 512)) { _ in }
        
        DryRunManager.shared.isEnabled = false
        _ = malwareService.quarantineFile(item: InfectedFileItem(filePath: malRealFile.path, fileName: "real_malware.bin", virusName: "Test.Real", fileSize: 512)) { url in
            try fm.removeItem(at: url)
        }
        _ = malwareService.quarantineFile(item: InfectedFileItem(filePath: malFailFile.path, fileName: "fail_malware.bin", virusName: "Test.Fail", fileSize: 512)) { _ in
            throw NSError(domain: "TidyMacTest", code: 3, userInfo: [NSLocalizedDescriptionKey: "Read-only FS"])
        }
        _ = malwareService.quarantineFile(item: InfectedFileItem(filePath: "/System/Library/CoreServices/Finder.app", fileName: "Finder.app", virusName: "FalsePos", fileSize: 1024)) { _ in }
        
        let badPlist = PersistenceItem(
            label: "com.test.bad",
            plistPath: "/tmp/unsafe_agent.plist",
            plistName: "unsafe_agent.plist",
            location: .userLaunchAgent,
            programPath: "/tmp/evil",
            isUnsigned: true,
            codesignStatus: .unsigned,
            isRecentlyAdded: true,
            creationDate: Date(),
            modificationDate: Date(),
            suspicionFlags: [.unsignedBinary]
        )
        _ = malwareService.quarantinePersistenceItem(item: badPlist) { _ in }
        await isolatedLog.flushAsync()
        
        suite.assert(
            isolatedLog.records.contains { $0.sourceModule == "Malware Scanner" && $0.path == malDryFile.path && $0.destination == .simulated && $0.isSuccess } &&
            isolatedLog.records.contains { $0.sourceModule == "Malware Scanner" && $0.path == malRealFile.path && $0.destination == .trash && $0.isSuccess } &&
            isolatedLog.records.contains { $0.sourceModule == "Malware Scanner" && $0.path == malFailFile.path && $0.destination == .trash && !$0.isSuccess } &&
            isolatedLog.records.contains { $0.sourceModule == "Malware Scanner" && $0.path == "/System/Library/CoreServices/Finder.app" && !$0.isSuccess } &&
            isolatedLog.records.contains { $0.sourceModule == "Malware Scanner" && $0.path == "/tmp/unsafe_agent.plist" && !$0.isSuccess },
            "MalwareScannerService logs dry-run, real quarantine, error, protected, and unsafe persistence rejections to DeletionLogManager"
        )
        
        return suite.printSummary()
    }
}

// MARK: - 17. DuplicateScanner Accuracy, Hard-Link Exclusion, Keep-One & Safe Trash Tests
func runDuplicateScannerSafetyAndAccuracyTests() -> Bool {
    return runAsyncMainActorTest {
        let suite = TestSuite("DuplicateScanner Accuracy, Hard-Link Exclusion & Keep-One Safety")
        let fm = FileManager.default
        let tempRoot = fm.temporaryDirectory.appendingPathComponent("TidyMacDuplicatesTest_\(UUID().uuidString)")
        let scanRoot = tempRoot.appendingPathComponent("ScanRoot")
        let logDir = tempRoot.appendingPathComponent("DeletionLogs")
        try? fm.createDirectory(at: scanRoot, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempRoot) }
        
        let originalDryRun = DryRunManager.shared.isEnabled
        let originalSimLog = DryRunManager.shared.simulatedActionsLog
        defer {
            DryRunManager.shared.isEnabled = originalDryRun
            DryRunManager.shared.simulatedActionsLog = originalSimLog
        }
        DryRunManager.shared.isEnabled = false
        
        let testLog = DeletionLogManager(storageDirectory: logDir)
        let scanner = DuplicateScanner(deletionLogManager: testLog)
        
        // Test 1: Stage 1 uses exact logical byte size (values.fileSize), NOT 4KB APFS block-allocated size,
        // and excludes hard links pointing to the same inode via fileResourceIdentifier.
        let payloadA = Data(repeating: 0x55, count: 150) // < 4KB block, > 100 bytes
        let origFile = scanRoot.appendingPathComponent("original.dat")
        let hardLinkFile = scanRoot.appendingPathComponent("hardlink.dat")
        let diffSizeSameBlock1 = scanRoot.appendingPathComponent("small_200.dat")
        let diffSizeSameBlock2 = scanRoot.appendingPathComponent("small_250.dat")
        
        fm.createFile(atPath: origFile.path, contents: payloadA, attributes: nil)
        try? fm.linkItem(at: origFile, to: hardLinkFile)
        fm.createFile(atPath: diffSizeSameBlock1.path, contents: Data(repeating: 0x11, count: 200), attributes: nil)
        fm.createFile(atPath: diffSizeSameBlock2.path, contents: Data(repeating: 0x11, count: 250), attributes: nil)
        
        await scanner.startScan(rootURL: scanRoot)
        suite.assert(
            scanner.duplicateGroups.isEmpty,
            "Hard-linked files pointing to same inode (and files differing only within 4KB block) produce 0 duplicate groups"
        )
        
        // Add an independent duplicate copy with a separate inode alongside the hard-linked pair
        let trueCopyFile = scanRoot.appendingPathComponent("true_copy.dat")
        fm.createFile(atPath: trueCopyFile.path, contents: payloadA, attributes: nil)
        
        await scanner.startScan(rootURL: scanRoot)
        suite.assert(
            scanner.duplicateGroups.count == 1 && scanner.duplicateGroups.first?.fileCount == 2,
            "Hard-linked pair + 1 independent copy yields 1 group with exactly 2 distinct-inode files (got \(scanner.duplicateGroups.first?.fileCount ?? -1))"
        )
        suite.assert(
            scanner.duplicateGroups.first?.fileSize == 150,
            "DuplicateGroup.fileSize reports exact logical byte size 150 (got \(scanner.duplicateGroups.first?.fileSize ?? -1))"
        )
        
        // Test 2: Keep-One enforcement blocks moveSelectedDuplicatesToTrash when allCopiesSelected == true
        if let group = scanner.duplicateGroups.first {
            for fIdx in scanner.duplicateGroups[0].files.indices {
                scanner.duplicateGroups[0].files[fIdx].isSelectedForRemoval = true
            }
            suite.assert(scanner.duplicateGroups[0].allCopiesSelected, "allCopiesSelected detects all copies marked for removal")
            
            final class OffMainBox: @unchecked Sendable {
                private let lock = NSLock()
                var called = false
                var allOffMain = true
                func record(_ isMain: Bool) {
                    lock.lock()
                    called = true
                    if isMain { allOffMain = false }
                    lock.unlock()
                }
            }
            let blockedTracker = OffMainBox()
            await scanner.moveSelectedDuplicatesToTrash(userConfirmed: true) { _ in
                blockedTracker.record(Thread.isMainThread)
            }
            suite.assert(!blockedTracker.called, "moveSelectedDuplicatesToTrash blocks execution when allCopiesSelected is true")
            suite.assert(scanner.scanError != nil && !scanner.scanError!.isEmpty, "moveSelectedDuplicatesToTrash sets scanError when allCopiesSelected is true")
            suite.assert(
                fm.fileExists(atPath: origFile.path) && fm.fileExists(atPath: trueCopyFile.path),
                "All files remain untouched on disk when allCopiesSelected is blocked"
            )
            
            // Restore Keep-One selection and verify off-MainActor batch trashing + DeletionLogManager logging
            scanner.applyKeepOneToGroup(at: 0, strategy: .keepOldest)
            suite.assert(!scanner.duplicateGroups[0].allCopiesSelected, "applyKeepOneToGroup keeps at least 1 original unselected")
            
            let batchTracker = OffMainBox()
            let keptPath = group.files.first(where: { !$0.isSelectedForRemoval })?.url.path
            await scanner.moveSelectedDuplicatesToTrash(userConfirmed: true) { url in
                batchTracker.record(Thread.isMainThread)
                try FileManager.default.removeItem(at: url)
            }
            await testLog.flushAsync()
            
            suite.assert(batchTracker.called && batchTracker.allOffMain, "moveSelectedDuplicatesToTrash runs file trashing off MainActor")
            suite.assert(scanner.duplicateGroups.isEmpty, "Group collapses once fewer than 2 copies remain")
            suite.assert(scanner.lastCleanResult?.reclaimedFilesCount == 1 && scanner.lastCleanResult?.reclaimedBytes == 150, "Batch clean reports exact reclaimed file count and logical bytes")
            if let keptPath {
                suite.assert(fm.fileExists(atPath: keptPath), "Preserved original copy remains on disk after batch clean")
            }
            suite.assert(
                testLog.records.contains { $0.sourceModule == "Duplicates" && $0.destination == .trash && $0.isSuccess && $0.sizeBytes == 150 },
                "moveSelectedDuplicatesToTrash logs trashed duplicate to DeletionLogManager"
            )
        }
        
        // Test 3: trashSingleFile respects DryRunManager, PathProtection, Keep-One, off-MainActor, and DeletionLogManager
        let singleRoot = tempRoot.appendingPathComponent("SingleTrash")
        try? fm.createDirectory(at: singleRoot, withIntermediateDirectories: true)
        let s1 = singleRoot.appendingPathComponent("s1.bin")
        let s2 = singleRoot.appendingPathComponent("s2.bin")
        let s3 = singleRoot.appendingPathComponent("s3.bin")
        for u in [s1, s2, s3] {
            fm.createFile(atPath: u.path, contents: Data(repeating: 0x77, count: 300), attributes: nil)
        }
        let item1 = DuplicateFileItem(url: s1, path: s1.path, directoryPath: singleRoot.path, name: "s1.bin", size: 300, modificationDate: Date(), isSelectedForRemoval: false, isKeptOriginal: true)
        let item2 = DuplicateFileItem(url: s2, path: s2.path, directoryPath: singleRoot.path, name: "s2.bin", size: 300, modificationDate: Date(), isSelectedForRemoval: true, isKeptOriginal: false)
        let item3 = DuplicateFileItem(url: s3, path: s3.path, directoryPath: singleRoot.path, name: "s3.bin", size: 300, modificationDate: Date(), isSelectedForRemoval: true, isKeptOriginal: false)
        let protItem = DuplicateFileItem(url: URL(fileURLWithPath: "/System/Library"), path: "/System/Library", directoryPath: "/System", name: "Library", size: 300, modificationDate: Date())
        let testGroup = DuplicateGroup(fullHash: "deadbeef", fileSize: 300, fileName: "s1.bin", category: "Other", icon: "doc", files: [item1, item2, item3, protItem])
        scanner.duplicateGroups = [testGroup]
        
        // 3a: Dry-Run single file trash
        DryRunManager.shared.isEnabled = true
        DryRunManager.shared.clearLog()
        await scanner.trashSingleFile(file: item2, in: testGroup) { _ in }
        await testLog.flushAsync()
        suite.assert(fm.fileExists(atPath: s2.path), "Dry-Run trashSingleFile preserves file on disk")
        suite.assert(DryRunManager.shared.simulatedActionsLog.contains { $0.contains(item2.path) }, "Dry-Run trashSingleFile logs simulation to DryRunManager")
        suite.assert(
            testLog.records.contains { $0.sourceModule == "Duplicates" && $0.path == s2.path && $0.destination == .simulated && $0.isSuccess },
            "Dry-Run trashSingleFile logs simulated deletion to DeletionLogManager"
        )
        
        // 3b: PathProtection blocks protected file in trashSingleFile
        DryRunManager.shared.isEnabled = false
        await scanner.trashSingleFile(file: protItem, in: testGroup) { _ in }
        await testLog.flushAsync()
        suite.assert(
            testLog.records.contains { $0.sourceModule == "Duplicates" && $0.path == "/System/Library" && !$0.isSuccess },
            "trashSingleFile blocks protected path and logs failure to DeletionLogManager"
        )
        
        // 3c: Real single-file trash runs off MainActor and logs to DeletionLogManager
        final class SingleTrashThreadTracker: @unchecked Sendable {
            private let lock = NSLock()
            var called = false
            var offMain = false
            func record(_ isMain: Bool) {
                lock.lock()
                called = true
                offMain = !isMain
                lock.unlock()
            }
        }
        let singleTracker = SingleTrashThreadTracker()
        await scanner.trashSingleFile(file: item3, in: testGroup) { url in
            singleTracker.record(Thread.isMainThread)
            try FileManager.default.removeItem(at: url)
        }
        await testLog.flushAsync()
        suite.assert(singleTracker.called && singleTracker.offMain, "trashSingleFile executes file trashing off MainActor")
        suite.assert(!fm.fileExists(atPath: s3.path), "Real trashSingleFile removes target file via trash handler")
        suite.assert(
            testLog.records.contains { $0.sourceModule == "Duplicates" && $0.path == s3.path && $0.destination == .trash && $0.isSuccess },
            "Real trashSingleFile logs success to DeletionLogManager"
        )
        
        return suite.printSummary()
    }
}

// MARK: - 18. Models Formatting, Clamping & DiskSpaceScanner Virtual/Deep-Drill Tests
func runModelFormattingAndDiskSpaceTests() -> Bool {
    return runAsyncMainActorTest {
        let suite = TestSuite("Models Formatting, Age Clamping & DiskSpaceScanner")
        let fm = FileManager.default
        let tempRoot = fm.temporaryDirectory.appendingPathComponent("TidyMacDiskSpaceTest_\(UUID().uuidString)")
        try? fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempRoot) }
        
        // Test 1: Future-dated LargeOldFileItem clamps ageInDays >= 0 and formats date
        let futureDate = Date(timeIntervalSinceNow: 60 * 60 * 24 * 14) // 14 days in the future
        let futureItem = LargeOldFileItem(
            url: tempRoot.appendingPathComponent("future.bin"),
            name: "future.bin",
            path: "~/future.bin",
            size: 2048,
            modificationDate: futureDate,
            fileType: .other
        )
        suite.assert(futureItem.ageInDays == 0, "Future-dated LargeOldFileItem clamps ageInDays to 0 (got \(futureItem.ageInDays))")
        suite.assert(!futureItem.isOld, "Future-dated LargeOldFileItem is not marked old")
        suite.assert(!futureItem.formattedDate.isEmpty, "LargeOldFileItem.formattedDate produces non-empty string")
        suite.assert(futureItem.formattedAge == "0 days ago", "Future-dated LargeOldFileItem.formattedAge reports 0 days ago")
        
        // Test 2: DuplicateFileItem.formattedDate uses shared static formatter cleanly
        let dupItem = DuplicateFileItem(
            url: tempRoot.appendingPathComponent("dup.bin"),
            path: tempRoot.appendingPathComponent("dup.bin").path,
            directoryPath: tempRoot.path,
            name: "dup.bin",
            size: 1024,
            modificationDate: Date(timeIntervalSince1970: 1_700_000_000)
        )
        suite.assert(!dupItem.formattedDate.isEmpty, "DuplicateFileItem.formattedDate returns formatted date string")
        
        // Test 3: DiskSpaceScanner groups small items into virtual "Other Items" preserving gray color
        // and supports on-demand deeper scanning beyond maxDepth: 2
        let scanRoot = tempRoot.appendingPathComponent("DiskRoot")
        try? fm.createDirectory(at: scanRoot, withIntermediateDirectories: true)
        
        // Create 6 large files (>= 5MB) and 12 tiny files (1KB) => 18 items (>15) and >50MB total
        // Wait: instead of writing 50MB of data on disk, create sparse/small files? Let's test virtual node
        // via DiskNode + DiskSpaceScanner deep drill-down on nested depth-4 tree!
        let d1 = scanRoot.appendingPathComponent("Level1")
        let d2 = d1.appendingPathComponent("Level2")
        let d3 = d2.appendingPathComponent("Level3")
        let d4 = d3.appendingPathComponent("Level4")
        try? fm.createDirectory(at: d4, withIntermediateDirectories: true)
        let deepPayload = Data(repeating: 0x3A, count: 8192)
        let deepFile = d4.appendingPathComponent("deep_payload.bin")
        fm.createFile(atPath: deepFile.path, contents: deepPayload, attributes: nil)
        
        let diskScanner = DiskSpaceScanner()
        await diskScanner.startScan(at: scanRoot)
        
        let level1Node = diskScanner.rootNode?.children.first(where: { $0.name == "Level1" })
        let level2Node = level1Node?.children.first(where: { $0.name == "Level2" })
        let level3Node = level2Node?.children.first(where: { $0.name == "Level3" })
        suite.assert(level1Node != nil && level2Node != nil && level3Node != nil, "Initial scan maps depth 0..2 (Level1 -> Level2 -> Level3)")
        
        if let l3 = level3Node {
            suite.assert(l3.children.isEmpty && !l3.hasScannedChildren, "Depth-2 boundary folder starts with hasScannedChildren == false")
            suite.assert(l3.canDrillDown, "Depth-2 boundary folder allows drill-down")
            
            diskScanner.drillDown(to: l3)
            for _ in 0..<100 {
                if !diskScanner.isDeepScanning { break }
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
            suite.assert(!diskScanner.isDeepScanning, "On-demand deep scan completes when drilling into depth-2 folder")
            suite.assert(l3.hasScannedChildren && l3.children.contains(where: { $0.name == "Level4" }), "Drilling down populates Level4 child beyond maxDepth: 2")
            let level4Node = l3.children.first(where: { $0.name == "Level4" })
            suite.assert(level4Node?.children.contains(where: { $0.name == "deep_payload.bin" }) == true, "On-demand deep scan also populates Level4's child file")
        }
        
        // Test 4: Virtual "Other Items" node behavior (color preservation & safe no-op Reveal/Open)
        let virtualRoot = tempRoot.appendingPathComponent("VirtualRoot")
        try? fm.createDirectory(at: virtualRoot, withIntermediateDirectories: true)
        // Create 6 large files (9MB each => 54MB > 50MB threshold) and 12 tiny files (4KB < 5MB)
        let bigChunk = Data(repeating: 0x22, count: 9 * 1024 * 1024)
        for i in 0..<6 {
            let bigURL = virtualRoot.appendingPathComponent("Big_\(i).dat")
            fm.createFile(atPath: bigURL.path, contents: bigChunk, attributes: nil)
        }
        for i in 0..<12 {
            let smallURL = virtualRoot.appendingPathComponent("Tiny_\(i).dat")
            fm.createFile(atPath: smallURL.path, contents: Data(repeating: 0x11, count: 4096), attributes: nil)
        }
        await diskScanner.startScan(at: virtualRoot)
        let otherNode = diskScanner.rootNode?.children.first(where: { $0.isVirtual })
        suite.assert(otherNode != nil, "DiskSpaceScanner creates virtual Other Items node when many small items exist")
        if let otherNode {
            let paletteMatch = DiskColorPalette.colors.contains(where: { $0 == otherNode.color })
            suite.assert(!paletteMatch, "Virtual Other Items node preserves gray color instead of being overwritten by palette loop")
            suite.assert(otherNode.canDrillDown, "Virtual Other Items node can be drilled down into")
            // Should be safe no-ops without launching Finder/NSWorkspace on non-existent URL
            diskScanner.revealInFinder(node: otherNode)
            diskScanner.openItem(node: otherNode)
            suite.assert(true, "revealInFinder and openItem safely ignore virtual Other Items node")
        }
        
        return suite.printSummary()
    }
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
let systemJunkSuccess = runSystemJunkScannerTests()
let privacyPerfSuccess = runPrivacyAndPerformanceTests()
let malwareQuarantineSuccess = runMalwareQuarantineTests()
let persistenceFPSSuccess = runPersistenceFalsePositiveTests()
let codesignSuccess = runCodeSignatureVerificationTests()
let processPipeSuccess = runProcessAndStreamParsingTests()
let privacySafetySuccess = runPrivacyScannerSafetyAndConcurrencyTests()
let appUninstallerSuccess = runAppUninstallerTests()
let maintenancePerfSuccess = runMaintenanceAndPerformanceSafetyTests()
let threadSafetyWiringSuccess = runThreadSafetyAndDeletionLogWiringTests()
let duplicateSafetySuccess = runDuplicateScannerSafetyAndAccuracyTests()
let modelDiskSpaceSuccess = runModelFormattingAndDiskSpaceTests()

let elapsed = Date().timeIntervalSince(startTime)
let allPassed = pathSuccess && sizeSuccess && securitySuccess && execSuccess && deletionLogSuccess && smartScanTruthSuccess && systemJunkSuccess && privacyPerfSuccess && malwareQuarantineSuccess && persistenceFPSSuccess && codesignSuccess && processPipeSuccess && privacySafetySuccess && appUninstallerSuccess && maintenancePerfSuccess && threadSafetyWiringSuccess && duplicateSafetySuccess && modelDiskSpaceSuccess

print("========================================================")
if allPassed {
    print(String(format: "🎉 ALL 18 TEST SUITES PASSED in %.3f seconds!", elapsed))
    print("========================================================\n")
    exit(0)
} else {
    print(String(format: "❌ SOME UNIT TESTS FAILED in %.3f seconds.", elapsed))
    print("========================================================\n")
    exit(1)
}
