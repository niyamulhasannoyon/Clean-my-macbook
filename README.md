# TidyMac 🚀

A modern, native macOS system cleaner and performance manager built with **SwiftUI** and designed specifically for macOS (macOS 13+).

---

## ✨ Features

- **Sidebar Navigation (`NavigationSplitView`)**: Clean categorized layout with custom SF Symbols, vibrant tint badges, and live disk stats in sidebar.
- **10 Core Sections**:
  1. **Smart Scan**: Hero one-click scanner with animated circular progress indicator and summary cards for Cleanup, Protection, and Speed.
  2. **System Junk**: Analysis of user caches, system logs, Xcode caches, mail attachments, and trash bins with item-level toggles.
  3. **Large & Old Files**: Identification of oversized files with filters by file type (Videos, Archives, Documents, DMGs).
  4. **Duplicates**: Hash-matched duplicate cluster detection and auto-selection for removal.
  5. **App Uninstaller**: Full uninstaller listing applications along with leftovers (Application Support, caches, preferences).
  6. **Privacy**: Erase browser history (Safari, Chrome), recent files, and audit app permissions (Camera, Mic, Full Disk Access).
  7. **Malware Scan**: Real-time malware shield toggle, scan scopes (LaunchDaemons, LaunchAgents, Browser extensions), and deep scanner.
  8. **Maintenance**: Actionable system scripts (Free up RAM, Flush DNS Cache, Rebuild Spotlight Index, Repair Disk Permissions).
  9. **Performance**: Real-time CPU usage, RAM breakdown, thermal state, and top resource-consuming processes.
  10. **Disk Space**: Multi-segment interactive disk usage gauge with actual macOS APFS storage metrics via `StorageModel`.
- **Menu Bar Extra (`MenuBarExtra`)**: Popover window status bar item showing live disk usage, memory gauge, quick 1-click clean, and app launcher.
- **Dark & Light Mode Support**: Native dynamic macOS system colors, vibrancy, and modern control materials.

---

## 🛠️ How to Open & Run

### 1. In Xcode
Open the project directly:
```bash
open TidyMac.xcodeproj
```
Select the **TidyMac** scheme and press **Cmd + R** to run.

### 2. Using Swift Package Manager / CLI
```bash
swift build
./.build/arm64-apple-macosx/debug/TidyMac
```

### 3. Prebuilt Application Bundle
```bash
open build/TidyMac.app
```
