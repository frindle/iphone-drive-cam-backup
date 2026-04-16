import Foundation

/// Inspects a USB drive URL and identifies which vehicle wrote to it
/// by looking for known root folder names.
struct VehicleDetector {

    /// Detect the vehicle type for a given USB drive root URL.
    /// - Parameter driveURL: The root URL of the USB drive as provided by the file picker
    /// - Returns: The detected VehicleType, or .unknown if no match found
    static func detect(at driveURL: URL) -> VehicleType {
        let fm = FileManager.default

        for vehicle in VehicleType.allCases {
            // Skip .unknown — it has no folder to look for
            guard let rootFolder = vehicle.usbRootFolder else { continue }

            let candidateURL = driveURL.appendingPathComponent(rootFolder)
            var isDirectory: ObjCBool = false

            // Check that the folder exists and is actually a directory (not a file)
            if fm.fileExists(atPath: candidateURL.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                return vehicle
            }
        }

        return .unknown
    }
}
