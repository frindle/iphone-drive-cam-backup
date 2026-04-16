import SwiftUI

/// The main screen. Shows:
/// 1. A button to select the USB drive
/// 2. Detected vehicle and file summary once a drive is selected
/// 3. A Start Upload button
struct ContentView: View {

    // SMB config loaded from UserDefaults
    @State private var config = SMBConfig.load()

    // The root URL of the selected USB drive
    @State private var driveURL: URL?

    // Detected vehicle type after scanning the drive
    @State private var detectedVehicle: VehicleType = .unknown

    // Files found on the drive after scanning
    @State private var files: [DashCamFile] = []

    // Whether the file picker sheet is open
    @State private var showingFilePicker = false

    // Whether the settings sheet is open
    @State private var showingSettings = false

    // Whether we're currently showing the upload screen
    @State private var showingUpload = false

    // Whether scanning is in progress
    @State private var isScanning = false

    // Error message from scanning
    @State private var scanError: String?

    // The uploader object — created fresh for each upload
    @StateObject private var uploader = SMBUploader()

    var body: some View {
        NavigationStack {
            Group {
                if showingUpload {
                    // Show upload progress
                    UploadView(uploader: uploader) {
                        showingUpload = false
                    }
                } else {
                    mainContent
                }
            }
            .navigationTitle("DriveCam Backup")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(config: $config)
            }
            // File picker — lets the user browse to the USB drive root in the Files app
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                handleDriveSelection(result)
            }
        }
    }

    // MARK: - Main content (shown when not uploading)

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 32) {

                // Settings warning banner
                if !config.isConfigured {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Configure your NAS settings before uploading.")
                            .font(.subheadline)
                        Spacer()
                        Button("Settings") { showingSettings = true }
                            .font(.subheadline.bold())
                    }
                    .padding()
                    .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                // Drive select button
                Button {
                    showingFilePicker = true
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: driveURL == nil ? "externaldrive.badge.plus" : "externaldrive.fill.badge.checkmark")
                            .font(.system(size: 48))
                            .foregroundStyle(driveURL == nil ? .blue : .green)
                        Text(driveURL == nil ? "Select USB Drive" : "Drive Selected — Tap to Change")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(32)
                    .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal)
                .disabled(isScanning)

                // Scanning indicator
                if isScanning {
                    ProgressView("Scanning drive…")
                }

                // Scan error
                if let scanError {
                    Text(scanError)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .padding(.horizontal)
                }

                // Vehicle and file summary — shown after a successful scan
                if driveURL != nil && !files.isEmpty {
                    VStack(spacing: 16) {
                        // Vehicle card
                        HStack(spacing: 16) {
                            Image(systemName: detectedVehicle.iconName)
                                .font(.system(size: 36))
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading) {
                                Text(detectedVehicle.displayName)
                                    .font(.title3.bold())
                                Text("Detected from USB drive")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

                        // File summary by folder
                        fileSummarySection

                        // Upload button
                        Button {
                            startUpload()
                        } label: {
                            Label("Start Upload", systemImage: "icloud.and.arrow.up")
                                .frame(maxWidth: .infinity)
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!config.isConfigured)
                    }
                    .padding(.horizontal)
                }

                // Empty state — drive selected but no dashcam files found
                if driveURL != nil && !isScanning && files.isEmpty && scanError == nil {
                    VStack(spacing: 12) {
                        Image(systemName: "film.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("No dashcam files found")
                            .font(.headline)
                        Text("Make sure you selected the root of the USB drive (not a subfolder).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }

                Spacer(minLength: 40)
            }
            .padding(.top)
        }
    }

    // MARK: - File summary breakdown by clip folder

    private var fileSummarySection: some View {
        let grouped = Dictionary(grouping: files, by: \.clipFolder)
        let totalSize = DriveScanner.totalSizeString(for: files)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Files Found")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(files.count) files · \(totalSize)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(detectedVehicle.clipFolders, id: \.self) { folder in
                if let folderFiles = grouped[folder] {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text(folder)
                            .font(.footnote)
                        Spacer()
                        Text("\(folderFiles.count) files")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions

    /// Called after the user picks a folder in the file picker
    private func handleDriveSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            scanError = "Could not open drive: \(error.localizedDescription)"
        case .success(let urls):
            guard let url = urls.first else { return }

            // Security-scoped access is required for files outside the app sandbox
            guard url.startAccessingSecurityScopedResource() else {
                scanError = "Permission denied to access this drive."
                return
            }

            driveURL = url
            scanError = nil
            files = []
            isScanning = true

            // Scan on a background thread so the UI stays responsive
            Task.detached(priority: .userInitiated) {
                let vehicle = VehicleDetector.detect(at: url)
                let scanned = (try? DriveScanner.scan(driveURL: url, vehicle: vehicle)) ?? []

                await MainActor.run {
                    detectedVehicle = vehicle
                    files = scanned
                    isScanning = false
                }
            }
        }
    }

    /// Start uploading all scanned files
    private func startUpload() {
        guard let url = driveURL else { return }
        showingUpload = true
        Task {
            await uploader.upload(files: files, vehicle: detectedVehicle, config: config)
            // Release security-scoped access once upload is done
            url.stopAccessingSecurityScopedResource()
        }
    }
}
