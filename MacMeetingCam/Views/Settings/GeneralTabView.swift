import SwiftUI

struct GeneralTabView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General Settings")
                .font(.headline)

            // Launch at login
            Toggle("Launch at Login", isOn: $appState.launchAtLogin)
                .accessibilityIdentifier("launchAtLoginToggle")

            // Show in menubar
            Toggle("Show in Menu Bar", isOn: $appState.showInMenubar)
                .accessibilityIdentifier("showInMenubarToggle")

            // Show in dock
            Toggle("Show in Dock", isOn: $appState.showInDock)
                .accessibilityIdentifier("showInDockToggle")

            // Auto-update
            Toggle("Automatically Check for Updates", isOn: $appState.autoCheckUpdates)
                .accessibilityIdentifier("autoCheckUpdatesToggle")

            Divider()

            // Segmentation quality picker
            HStack {
                Text("Segmentation Quality").frame(width: 160, alignment: .trailing)
                Picker("", selection: $appState.segmentationQuality) {
                    Text("Fast").tag(SegmentationQuality.fast)
                    Text("Balanced").tag(SegmentationQuality.balanced)
                    Text("Accurate").tag(SegmentationQuality.accurate)
                }
                .accessibilityIdentifier("segmentationQualityPicker")
            }

            Divider()

            // Version display
            HStack {
                Text("Version")
                    .foregroundColor(.secondary)
                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0")
                    .foregroundColor(.secondary)
                Text("(\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"))")
                    .foregroundColor(.secondary)
            }
            .font(.caption)
            .accessibilityIdentifier("versionDisplay")

            Spacer()
        }
        .padding(24)
    }
}
