import Foundation
import AMSMB2

/// Manages the SMB connection and uploads dashcam files to the Unraid NAS.
/// ObservableObject means SwiftUI views automatically update when published properties change.
@MainActor
class SMBUploader: ObservableObject {

    // MARK: - State (SwiftUI watches these and redraws the UI automatically)

    @Published var isUploading = false
    @Published var currentFileName = ""     // Name of the file currently being uploaded
    @Published var filesUploaded = 0        // How many files have finished
    @Published var totalFiles = 0           // Total files to upload
    @Published var bytesUploaded: Int64 = 0 // Bytes transferred so far across all files
    @Published var totalBytes: Int64 = 0    // Grand total bytes to transfer
    @Published var errorMessage: String?    // Set if something went wrong
    @Published var isDone = false           // Set to true when upload completes successfully

    private var cancelled = false

    /// Upload progress as a 0.0–1.0 fraction (used by the progress bar)
    var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(bytesUploaded) / Double(totalBytes)
    }

    // MARK: - Upload

    /// Connect to the NAS and upload all files.
    /// Call this from a SwiftUI button or Task { } block.
    ///
    /// - Parameters:
    ///   - files: Files to upload, from DriveScanner.scan()
    ///   - vehicle: The detected vehicle type (determines the NAS subfolder)
    ///   - config: SMB connection settings from SettingsView
    func upload(files: [DashCamFile], vehicle: VehicleType, config: SMBConfig) async {
        // Reset state for a fresh upload
        isUploading = true
        cancelled = false
        isDone = false
        errorMessage = nil
        filesUploaded = 0
        totalFiles = files.count
        totalBytes = files.reduce(0) { $0 + $1.size }
        bytesUploaded = 0

        // Build the SMB server URL: smb://hostname-or-ip
        guard let serverURL = URL(string: "smb://\(config.host)") else {
            errorMessage = "Invalid hostname: \(config.host)"
            isUploading = false
            return
        }

        // Set up credentials for the Samba connection
        let credential = URLCredential(
            user: config.username,
            password: config.password,
            persistence: .forSession
        )

        // Create the SMB client (from AMSMB2 library)
        let client = SMB2Manager(url: serverURL, credential: credential)

        // Connect to the share
        do {
            try await client.connectShare(config.share)
        } catch {
            errorMessage = "Could not connect to \\\\\\(config.host)\\\\\\(config.share)\n\(error.localizedDescription)"
            isUploading = false
            return
        }

        // Always disconnect when we're done, even if an error occurs
        defer {
            Task { try? await client.disconnectShare() }
        }

        // Upload each file one at a time
        for file in files {
            guard !cancelled else { break }

            currentFileName = file.fileName
            let fileStartBytes = bytesUploaded

            // Destination path on the NAS (relative to share root):
            // e.g. "DashCam/Tesla/RecentClips/2024-01-15_12-00-00-front.mp4"
            let destPath = "\(config.basePath)/\(vehicle.nasFolder)/\(file.relativePath)"

            // Make sure the destination directory exists
            // (createDirectory is safe to call even if the folder already exists)
            let destDir = (destPath as NSString).deletingLastPathComponent
            try? await client.createDirectory(atPath: destDir)

            do {
                // uploadItem streams the file from disk — avoids loading the whole
                // video into memory at once (important for large files)
                try await client.uploadItem(at: file.url, toPath: destPath) { [weak self] bytesSentThisChunk, totalSentForFile in
                    guard let self = self else { return false }
                    // Update total bytes (fileStartBytes tracks where this file started)
                    self.bytesUploaded = fileStartBytes + totalSentForFile
                    // Return false to cancel the upload mid-file
                    return !self.cancelled
                }
                filesUploaded += 1
                // Make sure bytesUploaded is accurate even if progress wasn't called for the last chunk
                bytesUploaded = fileStartBytes + file.size
            } catch {
                // Log the failure but keep going — don't abort everything for one bad file
                print("[SMBUploader] Failed: \(file.fileName) — \(error.localizedDescription)")
            }
        }

        isUploading = false
        isDone = !cancelled
    }

    /// Call this from the Cancel button in UploadView
    func cancel() {
        cancelled = true
    }
}
