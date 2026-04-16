# DriveCam Backup

iPhone app that reads dashcam footage from a USB drive and uploads it to a Samba share on an Unraid NAS. Supports Tesla and Rivian (more vehicles easy to add).

## How it works

1. Plug your dashcam USB drive into your iPhone via a USB-C adapter
2. Open the app, tap **Select USB Drive**, and navigate to the drive root in Files
3. The app detects the vehicle (Tesla or Rivian) from the folder structure
4. Tap **Start Upload** — files are copied to your NAS over SMB

Destination on NAS: `//host/share/BasePath/Vehicle/ClipFolder/filename`
Example: `//unraid.local/Media/DashCam/Tesla/RecentClips/2024-01-15_clip.mp4`

---

## Xcode Setup

### 1. Create the Xcode project

1. Open Xcode → **File > New > Project**
2. Choose **iOS > App**
3. Settings:
   - Product Name: `DriveCamBackup`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Uncheck "Include Tests" for now
4. Save it **inside** this repo folder (`iphone-drive-cam-backup/`)

### 2. Add the AMSMB2 Swift package

AMSMB2 handles the SMB connection to your NAS.

1. In Xcode: **File > Add Package Dependencies**
2. Enter URL: `https://github.com/amosavian/AMSMB2`
3. Select **Up to Next Major Version** from `2.0.0`
4. Click **Add Package**, then **Add to DriveCamBackup target**

### 3. Add the source files

Delete the auto-generated `ContentView.swift` that Xcode created, then drag these folders into the Xcode project navigator (check "Copy items if needed"):

```
DriveCamBackup/
├── DriveCamBackupApp.swift
├── Models/
│   ├── VehicleType.swift
│   └── SMBConfig.swift
├── Services/
│   ├── VehicleDetector.swift
│   ├── DriveScanner.swift
│   └── SMBUploader.swift
└── Views/
    ├── ContentView.swift
    ├── SettingsView.swift
    └── UploadView.swift
```

### 4. Add required Info.plist entries

In Xcode, select your app target → **Info** tab → add these keys:

| Key | Value |
|-----|-------|
| `NSLocalNetworkUsageDescription` | `Used to upload dashcam footage to your home NAS over SMB.` |
| `Privacy - Local Network Usage Description` | same as above |

### 5. Build and run

Connect your iPhone, select it as the run destination, and hit **Run** (⌘R).

---

## Rivian folder name

The Rivian vehicle folder name on the USB drive is currently set to `RIVIAN_DASHCAM` (placeholder).
Check your Rivian's USB drive root and update the value in `VehicleType.swift`:

```swift
case .rivian:
    return "RIVIAN_DASHCAM"  // ← update this
```

Also verify the clip subfolders (`clipFolders` in `VehicleType.swift`) match what Rivian creates.

---

## Adding another vehicle

1. Add a new case to `VehicleType` enum (`VehicleType.swift`)
2. Fill in `usbRootFolder`, `nasFolder`, and `clipFolders`
3. That's it — detection, scanning, and upload all use the enum automatically
