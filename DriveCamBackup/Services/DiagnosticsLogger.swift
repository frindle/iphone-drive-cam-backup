import Foundation
import UIKit
import ExternalAccessory

// A single log entry shown in DiagnosticsView
struct DiagnosticEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let category: Category
    let message: String

    enum Category {
        case system    // general info lines / section headers
        case volume    // mounted storage volumes
        case dashcam   // detected dashcam folders
        case accessory // MFi / USB accessories
        case error     // anything that failed

        var icon: String {
            switch self {
            case .system:    return "ℹ️"
            case .volume:    return "💾"
            case .dashcam:   return "📹"
            case .accessory: return "🔌"
            case .error:     return "❌"
            }
        }
    }

    var formattedTime: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: timestamp)
    }
}

/// Runs all diagnostic checks and publishes the results as an array of log entries.
/// DiagnosticsView observes this and redraws automatically.
@MainActor
class DiagnosticsLogger: ObservableObject {

    @Published var entries: [DiagnosticEntry] = []
    @Published var isRunning = false

    // MARK: - Entry point

    func run() {
        entries = []
        isRunning = true

        log("════════════════════════════", .system)
        log("  DriveCam Backup Diagnostics", .system)
        log("════════════════════════════", .system)
        log("iOS \(UIDevice.current.systemVersion)  •  \(UIDevice.current.model)", .system)
        log("Run at \(ISO8601DateFormatter().string(from: Date()))", .system)

        scanMountedVolumes()
        scanExternalAccessories()
        log("════ End of diagnostics ════", .system)

        isRunning = false
    }

    // MARK: - Volume scan

    /// Lists every volume iOS knows about (built-in, USB drives, network shares).
    /// When a USB-C hub is attached with a dashcam drive, the drive appears here.
    private func scanMountedVolumes() {
        log("", .system)
        log("── Mounted Volumes ──────────", .system)

        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeIsRemovableKey,
            .volumeIsEjectableKey,
            .volumeIsLocalKey,
            .volumeIsReadOnlyKey,
            .volumeIsInternalKey,
            .volumeIsRootFileSystemKey,
        ]

        guard let volumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: []
        ) else {
            log("FileManager.mountedVolumeURLs returned nil", .error)
            return
        }

        log("Total volumes visible: \(volumes.count)", .system)

        for (i, url) in volumes.enumerated() {
            let res = try? url.resourceValues(forKeys: Set(keys))

            let name      = res?.volumeName ?? "(unnamed)"
            let totalCap  = res?.volumeTotalCapacity.map { Int64($0) } ?? 0
            let availCap  = res?.volumeAvailableCapacity.map { Int64($0) } ?? 0
            let removable = res?.volumeIsRemovable == true
            let ejectable = res?.volumeIsEjectable == true
            let local     = res?.volumeIsLocal == true
            let readonly  = res?.volumeIsReadOnly == true
            let internal_ = res?.volumeIsInternal == true
            let isRoot    = res?.volumeIsRootFileSystem == true

            log("", .system)
            log("Volume \(i + 1): \"\(name)\"", .volume)
            log("  Path      : \(url.path)", .volume)
            log("  Capacity  : \(fmt(totalCap)) total, \(fmt(availCap)) free", .volume)
            log("  Removable : \(removable)  Ejectable: \(ejectable)", .volume)
            log("  Local     : \(local)  Internal: \(internal_)  RootFS: \(isRoot)", .volume)
            log("  Read-only : \(readonly)", .volume)

            // Try listing root contents (won't work for protected volumes but good to try)
            listRootContents(of: url, volumeName: name)

            // Check for known dashcam folder patterns
            checkDashcamFolders(on: url, volumeName: name)
        }
    }

    /// Tries to list the top-level items on a volume — tells us if we have read access.
    private func listRootContents(of url: URL, volumeName: String) {
        do {
            let items = try FileManager.default.contentsOfDirectory(atPath: url.path)
            log("  Root items (\(items.count)): \(items.prefix(10).joined(separator: ", "))\(items.count > 10 ? "…" : "")", .volume)
        } catch {
            log("  Root listing denied: \(error.localizedDescription)", .volume)
        }
    }

    /// Checks each volume for dashcam root folders from any known vehicle.
    /// If found, logs how many files are in it.
    private func checkDashcamFolders(on volumeURL: URL, volumeName: String) {
        // (vehicle label, folder name to look for)
        let candidates: [(String, String)] = [
            ("Tesla",            "TeslaCam"),
            ("Rivian [v1]",      "RIVIAN_DASHCAM"),   // placeholder — update once confirmed
            ("Rivian [v2]",      "RIVIAN"),
            ("Rivian [v3]",      "rivian"),
            ("Rivian [v4]",      "DashCam"),           // some Rivians may use this
        ]

        for (label, folder) in candidates {
            let candidate = volumeURL.appendingPathComponent(folder)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDir),
                  isDir.boolValue else { continue }

            log("✅ FOUND \(label) folder '\(folder)' on \"\(volumeName)\"", .dashcam)

            // Walk one level deep and count video files
            if let subfolders = try? FileManager.default.contentsOfDirectory(atPath: candidate.path) {
                log("   Subfolders: \(subfolders.joined(separator: ", "))", .dashcam)
                for sub in subfolders {
                    let subURL = candidate.appendingPathComponent(sub)
                    if let files = try? FileManager.default.contentsOfDirectory(atPath: subURL.path) {
                        let videos = files.filter { ["mp4","mov","ts","avi"].contains(($0 as NSString).pathExtension.lowercased()) }
                        log("   \(sub)/: \(files.count) items, \(videos.count) video files", .dashcam)
                    }
                }
            }
        }
    }

    // MARK: - Accessory scan

    /// Lists MFi-certified accessories connected via Lightning or USB-C.
    /// Most USB drives won't appear here (they're not MFi), but hubs or
    /// smart accessories might.
    private func scanExternalAccessories() {
        log("", .system)
        log("── External Accessories ─────", .system)

        let accessories = EAAccessoryManager.shared().connectedAccessories

        if accessories.isEmpty {
            log("No MFi accessories detected (normal for standard USB drives)", .accessory)
        } else {
            log("Found \(accessories.count) MFi accessor\(accessories.count == 1 ? "y" : "ies")", .accessory)
            for acc in accessories {
                log("🔌 \(acc.name)  by \(acc.manufacturer)", .accessory)
                log("   Model: \(acc.modelNumber)", .accessory)
                log("   HW: \(acc.hardwareRevision)  FW: \(acc.firmwareRevision)", .accessory)
                log("   Protocols: \(acc.protocolStrings.isEmpty ? "(none)" : acc.protocolStrings.joined(separator: ", "))", .accessory)
                log("   Connected: \(acc.isConnected)  Serial: \(acc.serialNumber)", .accessory)
            }
        }
    }

    // MARK: - Helpers

    private func fmt(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func log(_ message: String, _ category: DiagnosticEntry.Category) {
        entries.append(DiagnosticEntry(timestamp: Date(), category: category, message: message))
    }

    /// Full plain-text log, suitable for copying to clipboard or pasting into GitHub
    var fullLogText: String {
        entries.map { "[\($0.formattedTime)] \($0.message)" }.joined(separator: "\n")
    }
}
