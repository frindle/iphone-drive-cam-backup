import SwiftUI

/// Settings screen where the user enters their Unraid NAS connection details.
/// Shown as a sheet from the main screen.
struct SettingsView: View {

    // The config is passed in from ContentView so changes are reflected immediately
    @Binding var config: SMBConfig

    @Environment(\.dismiss) private var dismiss

    // Temporary local copies so we only save when the user taps Save
    @State private var host: String = ""
    @State private var share: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var basePath: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("NAS Connection")) {
                    LabeledField("Host / IP", text: $host, placeholder: "192.168.1.50 or unraid.local")
                    LabeledField("Share Name", text: $share, placeholder: "Media")
                    LabeledField("Username", text: $username, placeholder: "guest")
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }

                Section(
                    header: Text("Destination"),
                    footer: Text("Files are saved to: //Host/Share/Base Path/Vehicle/ClipFolder/filename")
                ) {
                    LabeledField("Base Path", text: $basePath, placeholder: "DashCam")
                }

                Section(header: Text("Example")) {
                    Text("Tesla clips go to:\n\(previewPath)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        config = SMBConfig(
                            host: host,
                            share: share,
                            username: username,
                            password: password,
                            basePath: basePath
                        )
                        config.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(host.isEmpty || share.isEmpty)
                }
            }
            .onAppear {
                // Populate fields with current saved values
                host     = config.host
                share    = config.share
                username = config.username
                password = config.password
                basePath = config.basePath
            }
        }
    }

    private var previewPath: String {
        let h = host.isEmpty ? "192.168.1.50" : host
        let s = share.isEmpty ? "Media" : share
        let b = basePath.isEmpty ? "DashCam" : basePath
        return "//\(h)/\(s)/\(b)/Tesla/RecentClips/"
    }
}

/// A simple labeled text field for use in a Form
private struct LabeledField: View {
    let label: String
    @Binding var text: String
    let placeholder: String

    init(_ label: String, text: Binding<String>, placeholder: String = "") {
        self.label = label
        self._text = text
        self.placeholder = placeholder
    }

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 100, alignment: .leading)
            TextField(placeholder, text: $text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
    }
}
