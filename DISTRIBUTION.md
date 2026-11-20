# TidyMac Distribution & Release Guide

This document outlines the distribution architecture, release pipeline, code-signing, notarization, and future Mac App Store roadmap for **TidyMac**.

---

## 1. Distribution Strategy: Developer ID vs Mac App Store

### Why Mac App Store is the Wrong First Target for TidyMac
The Mac App Store strictly mandates that all applications run inside **App Sandbox** (`com.apple.security.app-sandbox = true`). TidyMac's full system cleaner capabilities are fundamentally incompatible with App Sandbox:

1. **Elevated Administrator Privileges**: App Review strictly rejects apps invoking AppleScript with administrator privileges (`do shell script ... with administrator privileges`) used by `MaintenanceService` (DNS flush, periodic scripts, permission repair) and `PerformanceMonitor` (managing system daemons).
2. **Process Management**: Sandboxed apps cannot signal or terminate other applications or system daemons (`launchctl`, `killall -HUP mDNSResponder`, `sharedfilelistd`).
3. **Arbitrary Directory Access**: App Sandbox restricts file access to a container directory (`~/Library/Containers/<bundle-id>`). It forbids scanning arbitrary system caches (`/Library/Caches`), user library caches (`~/Library/Caches`), and other applications' application support data without individual user file dialogs.
4. **Third-Party CLI Execution**: Running external utilities (like ClamAV antivirus engine) from arbitrary system paths (`/opt/homebrew/bin/clamscan`) is blocked under sandbox policies.

This is why industry-standard macOS utilities (CleanMyMac X, OnyX, AppCleaner, DaisyDisk Standalone) ship as **Developer ID–signed and notarized applications** outside the Mac App Store.

---

## 2. Release Roadmap

### Immediate Release (Version 1.0.1) — Direct Distribution
- **Format**: Developer ID–signed and Apple-notarized `.dmg` disk image.
- **Architecture**: Universal Binary (`arm64` Apple Silicon + `x86_64` Intel 64-bit).
- **Runtime**: Hardened Runtime (`--options runtime`) with explicit entitlements in `TidyMac.entitlements`.
- **Updates**: Automated in-app updates powered by Sparkle (`SUFeedURL` pointing to `appcast.xml`).
- **Prerequisites**: $99/year Apple Developer Program account.

### Future Target — "TidyMac Lite" (Mac App Store Edition)
A separate, sandboxed target `TidyMacLite` engineered specifically to satisfy Mac App Store Review Guidelines:
- **Sandboxed**: Enforces `com.apple.security.app-sandbox = true`.
- **User-Selected Folders**: Uses `NSOpenPanel` and security-scoped bookmarks (`com.apple.security.files.user-selected.read-write`) so users explicitly grant access to specific folders (e.g. `~/Downloads`, external drives).
- **Safe Feature Set**:
  - Duplicate File Finder (within user-selected folders).
  - Large & Old File Analyzer (within user-selected folders).
  - Disk Treemap & Sunburst space visualization.
  - Safe User Application Uninstaller (limited to user-writable files).
- **Removed from Lite**: Drops all root/admin AppleScripts, `launchctl` management, `killall`, ClamAV CLI execution, and system-wide cache flush routines.

---

## 3. Developer ID Signing & Notarization Pipeline

### Prerequisites
1. **Apple Developer Account** ($99/year).
2. **Developer ID Application Certificate**: Installed in macOS Keychain (e.g., `Developer ID Application: Your Name (TEAMID)`).
3. **App Store Connect API Key** or **Keychain Profile** for `notarytool`.

### Generating an App Store Connect Notary Profile
Store your Apple credentials securely in your local macOS Keychain:
```bash
xcrun notarytool store-credentials "TidyMac-Notary" \
  --apple-id "developer@yourdomain.com" \
  --team-id "TEAMID1234" \
  --password "xxxx-xxxx-xxxx-xxxx" # App-specific password generated on appleid.apple.com
```

### Packaging & Notarizing the Universal DMG
TidyMac provides an automated pipeline in `scripts/create_dmg.sh`:
```bash
# 1. Set your Developer ID identity and notary profile
export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Company (TEAMID)"
export NOTARY_KEYCHAIN_PROFILE="TidyMac-Notary"

# 2. Run packaging script
./create_dmg.sh
```

The script automatically performs:
1. Universal binary build via SwiftPM (`arm64` + `x86_64`) merged with `lipo`.
2. Assembles `TidyMac.app` with `Info.plist`, `AppIcon.icns`, and `PrivacyInfo.xcprivacy`.
3. Code-signs with Hardened Runtime and entitlements (`TidyMac/Resources/TidyMac.entitlements`).
4. Generates compressed `TidyMac.dmg`.
5. Signs the `.dmg` container.
6. Submits the `.dmg` to Apple Notarization Service using `xcrun notarytool`.
7. Staples the notarization ticket to the DMG using `xcrun stapler staple`.
8. Verifies Gatekeeper acceptance using `spctl`.

---

## 4. GitHub Actions CI/CD Automation

The repository includes a ready-to-run GitHub Actions workflow in `.github/workflows/ci.yml`.

### Configuring Secrets in GitHub
To enable automated signing and notarization on GitHub Releases, configure the following secrets in your repository settings (**Settings → Secrets and variables → Actions**):

| Secret Name | Value Description |
|---|---|
| `DEVELOPER_ID_APPLICATION` | Full certificate name (e.g. `Developer ID Application: Your Name (TEAMID)`) |
| `DEVELOPER_ID_CERTIFICATE_BASE64` | Base64-encoded export of your `.p12` Developer ID Application certificate |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | Password protecting the exported `.p12` certificate |
| `NOTARY_API_KEY_BASE64` | Base64-encoded App Store Connect API Key (`AuthKey_KEYID.p8`) |
| `NOTARY_KEY_ID` | 10-character Key ID from App Store Connect |
| `NOTARY_ISSUER_ID` | UUID Issuer ID from App Store Connect |

When pushing a tag (e.g., `git tag v1.0.1 && git push origin v1.0.1`), GitHub Actions automatically compiles, tests, signs, notarizes, staples, and attaches the resulting `TidyMac.dmg` to the release.

---

## 5. Sparkle Auto-Update Integration

TidyMac includes Sparkle update keys in `TidyMac/Resources/Info.plist`:
- `SUFeedURL`: `https://updates.tidymac.app/appcast.xml`
- `SUPublicEDKey`: Public Ed25519 signing key generated by Sparkle's `bin/generate_keys` tool.
- `SUEnableAutomaticChecks`: Set to `true`.

### Publishing an Update
1. Build and notarize the new version DMG (`build/TidyMac.dmg`).
2. Sign the DMG with Sparkle's private Ed25519 key:
   ```bash
   ./bin/sign_update build/TidyMac.dmg
   ```
3. Update `appcast.xml` with the new version number, file size, download URL, and Ed25519 signature.
4. Upload `appcast.xml` and the notarized DMG to your update hosting bucket/server.

---

## 6. Safety & Deletion Safeguards

TidyMac implements multi-layered protections to guarantee user data safety:
- **Immutable Path Protection (`PathProtection.swift`)**: Hardcoded rejection of core OS and user personal roots (`/System`, `/bin`, `/usr`, `/Library`, `~/.ssh`, `~/.gnupg`, Keychains).
- **Trash-First Deletion**: All deletions prioritize moving files to the macOS Trash via `FileManager.trashItem` so actions can be undone.
- **Activity & Deletion History (`DeletionLogManager.swift`)**: Every trashing or deletion operation is permanently logged to `~/Library/Application Support/TidyMac/deletion_history.json` and reviewable in Settings.
- **Dry-Run Simulation (`DryRunManager.swift`)**: Allows users to preview every file removal without modifying any disk data.
- **Browser Protection**: Gracefully checks for active browser sessions before clearing history or cookies and prompts the user before terminating browsers.
