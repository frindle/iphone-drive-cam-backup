import Foundation

/// Connection details for the Unraid Samba share.
/// Loaded from and saved to UserDefaults so settings persist between launches.
struct SMBConfig {
    var host: String      // IP or hostname, e.g. "192.168.1.50" or "unraid.local"
    var share: String     // Share name as configured in Unraid, e.g. "Media"
    var username: String  // Samba user (can be "guest" if your share allows it)
    var password: String
    var basePath: String  // Folder inside the share where clips go, e.g. "DashCam"
                          // Tesla ends up at: //host/share/DashCam/Tesla/RecentClips/

    // MARK: - Persistence

    private enum Keys {
        static let host     = "smb_host"
        static let share    = "smb_share"
        static let username = "smb_username"
        static let password = "smb_password"
        static let basePath = "smb_basePath"
    }

    /// Returns true if the minimum required fields are filled in
    var isConfigured: Bool {
        !host.isEmpty && !share.isEmpty
    }

    /// Load saved settings from UserDefaults (or return empty defaults)
    static func load() -> SMBConfig {
        let d = UserDefaults.standard
        return SMBConfig(
            host:     d.string(forKey: Keys.host)     ?? "",
            share:    d.string(forKey: Keys.share)    ?? "",
            username: d.string(forKey: Keys.username) ?? "",
            password: d.string(forKey: Keys.password) ?? "",
            basePath: d.string(forKey: Keys.basePath) ?? "DashCam"
        )
    }

    /// Save current settings to UserDefaults
    func save() {
        let d = UserDefaults.standard
        d.set(host,     forKey: Keys.host)
        d.set(share,    forKey: Keys.share)
        d.set(username, forKey: Keys.username)
        d.set(password, forKey: Keys.password)
        d.set(basePath, forKey: Keys.basePath)
    }
}
