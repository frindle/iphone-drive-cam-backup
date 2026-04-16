import Foundation

/// All the vehicle types the app knows how to handle.
/// Add new cases here when supporting additional vehicles.
enum VehicleType: String, CaseIterable {
    case tesla
    case rivian
    case unknown

    // Human-readable name shown in the UI
    var displayName: String {
        switch self {
        case .tesla:   return "Tesla"
        case .rivian:  return "Rivian"
        case .unknown: return "Unknown Vehicle"
        }
    }

    // SF Symbol icon name for each vehicle
    var iconName: String {
        switch self {
        case .tesla:   return "bolt.car"
        case .rivian:  return "truck.box"
        case .unknown: return "questionmark.circle"
        }
    }

    // The root folder name this vehicle writes to on the USB drive.
    // The app detects which vehicle the drive belongs to by looking for this folder.
    var usbRootFolder: String? {
        switch self {
        case .tesla:
            return "TeslaCam"
        case .rivian:
            // TODO: Confirm exact folder name from your Rivian's USB drive root.
            // Common values seen: "RIVIAN_DASHCAM", "RIVIAN", "Rivian"
            return "RIVIAN_DASHCAM"
        case .unknown:
            return nil
        }
    }

    // The subfolder used under the NAS base path for this vehicle.
    // e.g. if base path is "DashCam", Tesla files go to "DashCam/Tesla/"
    var nasFolder: String {
        switch self {
        case .tesla:   return "Tesla"
        case .rivian:  return "Rivian"
        case .unknown: return "Unknown"
        }
    }

    // The clip subfolders found inside the vehicle's USB root folder.
    // These are mirrored 1:1 to the NAS destination.
    var clipFolders: [String] {
        switch self {
        case .tesla:
            // Tesla writes to these three subfolders
            return ["RecentClips", "SavedClips", "SentryClips"]
        case .rivian:
            // TODO: Confirm Rivian's clip subfolder names from the USB drive
            return ["dashcam", "saved"]
        case .unknown:
            return []
        }
    }
}
