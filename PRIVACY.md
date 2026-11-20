# TidyMac Privacy Policy

**Effective Date:** November 20, 2026  
**Last Updated:** November 20, 2026

TidyMac is designed with a strict **Local-First, Zero-Telemetry Privacy Architecture**. We believe system cleaning and maintenance software should respect user privacy above all else.

---

## 1. Zero Data Collection & Zero Telemetry

- **No Remote Servers**: TidyMac communicates with zero analytics servers, tracking platforms, or advertising networks.
- **No Analytics / Telemetry**: We do not collect crash reports remotely, do not track module usage, and do not log file paths to remote endpoints.
- **100% On-Device Execution**: All storage calculations, duplicate scans, privacy trace detections, and malware audits run entirely locally on your Mac's CPU and disk.

---

## 2. Apple Required-Reason APIs (macOS Privacy Manifest)

In compliance with Apple's macOS Privacy Manifest standard (`PrivacyInfo.xcprivacy`), TidyMac declares the following system APIs and their sole purposes:

| API Category | Apple Reason Code | Purpose in TidyMac |
|---|---|---|
| **Disk Space** (`NSPrivacyAccessedAPICategoryDiskSpace`) | `E174.1` | Query available and total APFS/HFS+ volume capacity to calculate disk space reclaimed. |
| **File Timestamps** (`NSPrivacyAccessedAPICategoryFileTimestamp`) | `C617.1` | Inspect last modified and last accessed dates to identify old files and sort files by age. |
| **System Boot Time** (`NSPrivacyAccessedAPICategorySystemBootTime`) | `35F9.1` | Measure system uptime and evaluate CPU/memory metrics in the Performance Monitor. |
| **User Defaults** (`NSPrivacyAccessedAPICategoryUserDefaults`) | `CA92.1` | Save user application preferences (such as Dry-Run simulation toggle and scan thresholds) locally in `NSUserDefaults`. |

---

## 3. Full Disk Access & File System Operations

- **Permissions**: TidyMac requires Full Disk Access (FDA) solely to inspect application caches, logs, and duplicate items located in protected user directories (`~/Library`).
- **Path Safeguards**: TidyMac contains immutable path protection rules (`PathProtection.swift`) that unconditionally block deletions across system-critical locations (`/System`, `/bin`, `/usr`, `/Library`, `~/.ssh`, Keychains, and core user directories).
- **Trashing Preference**: Whenever supported by the operating system, deleted files are moved to the user's macOS Trash rather than permanently deleted, enabling full user recovery.
- **Activity History**: All cleaning operations are logged locally to `~/Library/Application Support/TidyMac/deletion_history.json`. This log never leaves your computer and can be purged at any time in **Settings → Deletion & Activity History**.

---

## 4. Software Updates

If automatic update checks are enabled via Sparkle, the app contacts `https://updates.tidymac.app/appcast.xml` over HTTPS to check for new release versions. No personally identifiable information or system metrics are transmitted during update checks.

---

## 5. Contact & Support

For questions regarding TidyMac security or privacy:
- **Email:** support@tidymac.app
- **Website:** [https://tidymac.app](https://tidymac.app)
- **GitHub:** [https://github.com/niyamulhasan/TidyMac](https://github.com/niyamulhasan/TidyMac)
