import Foundation

/// A single dashcam video file found on the USB drive.
struct DashCamFile: Identifiable {
    let id = UUID()
    let url: URL              // Full path to the file on the USB drive
    let relativePath: String  // Path relative to vehicle root, e.g. "RecentClips/clip.mp4"
    let size: Int64           // File size in bytes
    let clipFolder: String    // Which subfolder it came from, e.g. "RecentClips"

    var fileName: String { url.lastPathComponent }
    var sizeString: String { ByteCountFormatter.string(fromByteCount: size, countStyle: .file) }
}

/// Walks the USB drive and collects all dashcam video files for a given vehicle.
struct DriveScanner {

    // File extensions considered dashcam footage
    private static let videoExtensions: Set<String> = ["mp4", "mov", "avi", "ts"]

    /// Scan the drive and return all video files found under the vehicle's root folder.
    /// - Parameters:
    ///   - driveURL: Root URL of the USB drive
    ///   - vehicle: Detected vehicle type (determines which folders to look in)
    /// - Returns: List of DashCamFile objects, sorted by clip folder then filename
    static func scan(driveURL: URL, vehicle: VehicleType) throws -> [DashCamFile] {
        guard let rootFolderName = vehicle.usbRootFolder else { return [] }

        let vehicleRootURL = driveURL.appendingPathComponent(rootFolderName)
        let fm = FileManager.default
        var results: [DashCamFile] = []

        for clipFolder in vehicle.clipFolders {
            let clipFolderURL = vehicleRootURL.appendingPathComponent(clipFolder)

            // Skip if this vehicle doesn't have this subfolder on this drive
            guard fm.fileExists(atPath: clipFolderURL.path) else { continue }

            guard let enumerator = fm.enumerator(
                at: clipFolderURL,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                // Only include known video extensions
                let ext = fileURL.pathExtension.lowercased()
                guard videoExtensions.contains(ext) else { continue }

                // Skip files that aren't regular files
                let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                guard resourceValues?.isRegularFile == true else { continue }

                let size = Int64(resourceValues?.fileSize ?? 0)

                // Relative path mirrors the NAS destination:
                // "RecentClips/2024-01-15_12-00-00-front.mp4"
                let relativePath = clipFolder + "/" + fileURL.lastPathComponent

                results.append(DashCamFile(
                    url: fileURL,
                    relativePath: relativePath,
                    size: size,
                    clipFolder: clipFolder
                ))
            }
        }

        // Sort: by clip folder order first, then by filename
        return results.sorted {
            if $0.clipFolder != $1.clipFolder {
                let order = vehicle.clipFolders
                let aIndex = order.firstIndex(of: $0.clipFolder) ?? 999
                let bIndex = order.firstIndex(of: $1.clipFolder) ?? 999
                return aIndex < bIndex
            }
            return $0.fileName < $1.fileName
        }
    }

    /// Human-readable total size for a list of files, e.g. "4.2 GB"
    static func totalSizeString(for files: [DashCamFile]) -> String {
        let total = files.reduce(0) { $0 + $1.size }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }
}
