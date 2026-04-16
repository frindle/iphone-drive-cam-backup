import SwiftUI

/// Shown while an upload is in progress (or after it completes).
/// Displays a progress bar, current file, and a cancel/done button.
struct UploadView: View {

    @ObservedObject var uploader: SMBUploader

    // Called when the user taps Done or Cancel and wants to go back to the main screen
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Status icon — spinner while uploading, checkmark when done
            if uploader.isDone {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)
            } else {
                ProgressView()
                    .controlSize(.large)
            }

            // Title
            Text(uploader.isDone ? "Upload Complete" : "Uploading…")
                .font(.title2.bold())

            // Progress bar (only shown while uploading)
            if !uploader.isDone {
                VStack(spacing: 8) {
                    ProgressView(value: uploader.progress)
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 300)

                    // Current file name
                    Text(uploader.currentFileName)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 300)
                }
            }

            // File and byte counts
            VStack(spacing: 4) {
                Text("\(uploader.filesUploaded) of \(uploader.totalFiles) files")
                    .font(.subheadline)

                Text("\(byteString(uploader.bytesUploaded)) of \(byteString(uploader.totalBytes))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Cancel button while uploading, Done button when finished
            if uploader.isDone {
                Button("Done") {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button(role: .destructive) {
                    uploader.cancel()
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(maxWidth: 300)
            }
        }
        .padding()
        // If the user cancels mid-upload, go back to main screen after a short delay
        .onChange(of: uploader.isUploading) { _, stillUploading in
            if !stillUploading && !uploader.isDone {
                onDismiss()
            }
        }
    }

    private func byteString(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
