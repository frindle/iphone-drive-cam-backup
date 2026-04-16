import SwiftUI

/// Shows a live log of everything the app can see when connected to a USB-C hub.
/// Auto-runs on first load so you get results immediately when plugging in.
struct DiagnosticsView: View {

    @StateObject private var logger = DiagnosticsLogger()
    @State private var copied = false

    var body: some View {
        NavigationStack {
            Group {
                if logger.entries.isEmpty && !logger.isRunning {
                    emptyState
                } else {
                    logList
                }
            }
            .navigationTitle("Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    // Copy full log to clipboard
                    if !logger.entries.isEmpty {
                        Button {
                            UIPasteboard.general.string = logger.fullLogText
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                        } label: {
                            Image(systemName: copied ? "checkmark" : "doc.on.clipboard")
                        }
                    }

                    // Re-run button
                    Button {
                        logger.run()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(logger.isRunning)
                }
            }
            // Auto-run the moment the tab appears
            .onAppear {
                if logger.entries.isEmpty {
                    logger.run()
                }
            }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("Tap ↻ to scan connected devices")
                .foregroundStyle(.secondary)
        }
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(logger.entries) { entry in
                    LogRow(entry: entry)
                        .id(entry.id)
                        .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
                        .listRowSeparator(.hidden)
                        .listRowBackground(rowBackground(for: entry))
                }
            }
            .listStyle(.plain)
            .font(.system(.caption, design: .monospaced))
            // Scroll to bottom as new entries come in
            .onChange(of: logger.entries.count) { _, _ in
                if let last = logger.entries.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private func rowBackground(for entry: DiagnosticEntry) -> Color {
        switch entry.category {
        case .dashcam:   return .green.opacity(0.12)
        case .error:     return .red.opacity(0.10)
        case .system where entry.message.hasPrefix("──") || entry.message.hasPrefix("══"):
            return .secondary.opacity(0.08)
        default:         return .clear
        }
    }
}

private struct LogRow: View {
    let entry: DiagnosticEntry

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(entry.formattedTime)
                .foregroundStyle(.tertiary)
                .fixedSize()
            Text(entry.message)
                .foregroundStyle(textColor)
                .textSelection(.enabled)  // user can tap-hold to copy individual lines
        }
    }

    private var textColor: Color {
        switch entry.category {
        case .dashcam:  return .green
        case .error:    return .red
        case .volume:   return .primary
        default:        return .secondary
        }
    }
}
