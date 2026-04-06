import SwiftUI

struct PopoverView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 12) {
            // Mini preview (placeholder)
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black)
                .aspectRatio(16/9, contentMode: .fit)
                .overlay(
                    Text("Preview")
                        .foregroundColor(.gray)
                        .font(.caption)
                )
                .accessibilityIdentifier("popoverPreview")

            // Status indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(testableStatusColor)
                    .frame(width: 7, height: 7)
                Text(testableStatusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .accessibilityIdentifier("popoverStatus")

            // Quick toggle buttons
            HStack(spacing: 6) {
                QuickToggleButton(
                    label: "BG",
                    icon: "photo",
                    isActive: appState.backgroundEffectEnabled,
                    action: { appState.toggleBackgroundEffect() }
                )
                .accessibilityIdentifier("bgToggle")

                QuickToggleButton(
                    label: "Freeze",
                    icon: "pause",
                    isActive: appState.pipelineMode == .frozen,
                    action: { appState.toggleFreeze() }
                )
                .accessibilityIdentifier("freezeToggle")

                QuickToggleButton(
                    label: "Loop",
                    icon: "arrow.2.squarepath",
                    isActive: appState.pipelineMode == .looping,
                    action: { appState.toggleLoop() }
                )
                .accessibilityIdentifier("loopToggle")
            }

            Divider()

            // Settings & Quit
            HStack {
                Button("Settings") { /* open settings */ }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("settingsButton")
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("quitButton")
            }
            .font(.caption)
        }
        .padding(16)
        .frame(width: 280)
    }

    // MARK: - Status Logic (exposed for testing)

    var testableStatusColor: Color {
        switch appState.pipelineMode {
        case .live: return .green
        case .frozen: return .yellow
        case .looping: return .red
        }
    }

    var testableStatusText: String {
        switch appState.pipelineMode {
        case .live:
            return appState.backgroundEffectEnabled ? "Live \u{2014} Background Effect Active" : "Live"
        case .frozen: return "Frozen"
        case .looping: return "Looping"
        }
    }
}

struct QuickToggleButton: View {
    let label: String
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(label)
                    .font(.system(size: 10))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isActive ? Color.accentColor : Color.gray.opacity(0.2))
            .foregroundColor(isActive ? .white : .secondary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
