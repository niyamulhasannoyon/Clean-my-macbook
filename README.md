# TidyMac 🚀

A modern, native macOS system cleaner and performance manager built with **SwiftUI** and designed specifically for macOS (macOS 13+ Ventura, Sonoma, Sequoia).

---

## ✨ Features

- **Sidebar Navigation (`NavigationSplitView`)**: Clean categorized layout with custom SF Symbols, vibrant tint badges, and live disk stats in sidebar.
- **Dry-Run Simulation Mode**: Global simulation toggle to test and preview scan and cleanup actions safely without deleting any files on disk. Includes simulated action logs and real-time badges.
- **Built-in Path Protection Engine**: Permanent safeguards protecting macOS core directories (`/System`, `/bin`, `/sbin`, `/usr`, `/Library`, `/Applications`), user home directory root, essential user folders (`Desktop`, `Documents`, `Downloads`), SSH keys (`~/.ssh`), shell profiles (`.zshrc`, `.bash_profile`), and Keychains from accidental deletion.
- **Robust Size Calculation**: APFS/HFS+ fast recursive sizing engine handling single files, directories, symlink loop avoidance, and zero-byte files.
- **Comprehensive Error Handling & Loading States**: Real-time progress spinners, scan step status updates, dismissible error banners with retry buttons, and smooth animated state transitions across all 10 core modules.
- **Original macOS App Icon**: Custom high-resolution squircle icon design based on SF Symbols (`sparkles` + `internaldrive`), available up to 1024x1024 Retina with `.icns` bundle integration.
- **10 Core System Modules**:
  1. **Smart Scan**: Hero one-click unified scanner with animated circular progress indicator, review sheet, and summary cards for Cleanup, Protection, and Speed.
  2. **System Junk**: Analysis of user app caches, system logs, Xcode derived data, mail attachments, and trash bins with item-level toggles.
  3. **Large & Old Files**: Identification of oversized files (>100MB) with filters by file type (Videos, Archives, Documents, DMGs).
  4. **Duplicates**: 3-stage hash-matched duplicate cluster detection (Exact byte size → partial fast hash → SHA-256) and auto-selection for removal.
  5. **App Uninstaller**: Full uninstaller listing applications along with leftovers (Application Support, caches, preferences, orphaned files).
  6. **Privacy**: Erase browser history (Safari, Chrome, Firefox, Edge, Brave), recent files, and audit app permissions (Camera, Mic, Full Disk Access).
  7. **Malware Scan**: Real-time malware shield toggle, scan scopes (LaunchDaemons, LaunchAgents, Browser extensions), and ClamAV integration.
  8. **Maintenance**: Actionable system scripts (Free up RAM, Flush DNS Cache, Rebuild Spotlight Index, Repair Disk Permissions).
  9. **Performance**: Real-time CPU usage, RAM breakdown, thermal state, and top resource-consuming processes.
  10. **Disk Space**: Multi-segment interactive disk usage gauge with Treemap & Sunburst visualizers for directories and APFS storage metrics.
- **Menu Bar Extra (`MenuBarExtra`)**: Popover window status bar item showing live disk usage, memory gauge, quick 1-click clean, and app launcher.
- **Dark & Light Mode Support**: Native dynamic macOS system colors, vibrancy, and modern control materials.

---

## 🛡️ macOS Gatekeeper Bypass ("Right click > Open")

যেহেতু অ্যাপটি লোকালভাবে বিল্ড করা এবং এতে অ্যাপল ডেভেলপার একাউন্টের পেইড নোটারাইজেশন টিকেট নেই, তাই macOS Gatekeeper অ্যাপটি প্রথমবার রান করার সময় একটি সিকিউরিটি ওয়ার্নিং দেখাতে পারে:
> *"TidyMac can't be opened because Apple cannot check it for malicious software"* অথবা *"unidentified developer"*.

এই ওয়ার্নিংটি বাইপাস করে সহজেই অ্যাপটি ওপেন করার ৩টি উপায় নিচে দেওয়া হলো:

### পদ্ধতি ১: Right-click > Open (সবচেয়ে সহজ ও রিকমেন্ডেড পদ্ধতি)
1. **Finder** ওপেন করুন এবং যেখানে `TidyMac.app` আছে (যেমন `/Applications` ফোল্ডার বা প্রোজেক্টের `build/` ফোল্ডার) সেখানে যান।
2. `TidyMac.app` ফাইলের উপর **Right-click** (অথবা কীবোর্ডের **Control** বাটন চেপে ধরে ক্লিক) করুন।
3. মেনু থেকে **"Open"** সিলেক্ট করুন।
4. একটি ডায়ালগ বক্স আসবে যেখানে লেখা থাকবে অ্যাপটির ডেভেলপার ভেরিফাই করা নেই। এখানে **"Open"** বাটনে ক্লিক করুন।
5. ব্যস! একবার এই পদ্ধতিতে খুললে macOS এই অ্যাপটিকে সেফ হিসেবে রেজিস্টার করে নেবে এবং পরবর্তীতে ডাবল ক্লিকেই স্বাভাবিকভাবে ওপেন হবে।

---

### পদ্ধতি ২: System Settings > Privacy & Security থেকে অনুমতি দেওয়া
1. আপনার ম্যাকের **System Settings** (বা System Preferences) ওপেন করুন।
2. বাম পাশের মেনু থেকে **Privacy & Security** অপশনে যান।
3. স্ক্রল করে নিচের দিকে **Security** সেকশনে যান।
4. সেখানে দেখতে পাবেন: *"TidyMac was blocked from use because it is not from an identified developer."*
5. এর পাশে থাকা **"Open Anyway"** বাটনে ক্লিক করুন এবং আপনার ম্যাকের পাসওয়ার্ড বা Touch ID দিয়ে অনুমোদন দিন।

---

### পদ্ধতি ৩: Terminal Command (Quarantine Flag রিমুভ)
টার্মিনালে নিচের কমান্ডটি রান করলেই Gatekeeper এর Quarantine অ্যাট্রিবিউট রিমুভ হয়ে যাবে:

```bash
# Applications ফোল্ডারে থাকলে:
xattr -cr /Applications/TidyMac.app

# অথবা লোকাল build ফোল্ডারে থাকলে:
xattr -cr build/TidyMac.app
```

---

## 🧪 Unit Testing

প্রোজেক্টে পাথ-প্রোটেকশন এবং সাইজ ক্যালকুলেশন লজিকের জন্য একটি ডেডিকেটেড ইউনিট টেস্ট স্যুট অন্তর্ভুক্ত রয়েছে (৩৫টি সিকিউরিটি পাথ টেস্ট + ৮টি সাইজ ইঞ্জিন টেস্ট):

```bash
swift run UnitTests
```

---

## 📦 Release Build & DMG Creation

### ১. রিলিজ বিল্ড ও .app এক্সপোর্ট
রিলিজ বাইনারি কম্পাইল করতে এবং কোড-সাইন্ড `.app` বানাতে:

```bash
swift build -c release
```

### ২. DMG প্যাকেজিং স্ক্রিপ্ট রান করা
প্রোজেক্টের রুট ডিরেক্টরিতে একটি স্বয়ংক্রিয় DMG ক্রিয়েশন স্ক্রিপ্ট দেওয়া রয়েছে:

```bash
./create_dmg.sh
# অথবা
./scripts/create_dmg.sh
```

এই স্ক্রিপ্টটি:
- অটোমেটিক রিলিজ বাইনারি তৈরি করে
- `build/TidyMac.app` বান্ডেল প্রস্তুত ও সাইন করে
- কাস্টম অ্যাপ আইকন ভলিউমে সেট করে
- `/Applications` শর্টকাট সিমলিংক অ্যাড করে
- কম্প্রেসড রিড-অনলি `build/TidyMac.dmg` তৈরি করে।

---

## 🛠️ Development & Debug Run

### Swift Package Manager CLI:
```bash
# Debug build
swift build

# Run application directly
./.build/arm64-apple-macosx/debug/TidyMac
```

### Prebuilt Application:
```bash
open build/TidyMac.app
```
