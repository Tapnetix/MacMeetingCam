import SwiftUI
import KeyboardShortcuts

struct HotkeysTabView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Global Keyboard Shortcuts")
                .font(.headline)

            ForEach(HotkeyAction.allCases, id: \.self) { action in
                HStack {
                    Text(action.displayName)
                        .frame(width: 200, alignment: .leading)
                    KeyboardShortcuts.Recorder(for: action.shortcutName)
                    Spacer()
                }
            }

            Text("Shortcuts work globally, even when the app is in the background.")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("Restore Defaults") {
                for action in HotkeyAction.allCases {
                    KeyboardShortcuts.reset(action.shortcutName)
                }
            }
            .accessibilityIdentifier("restoreDefaultsButton")

            Spacer()
        }
        .padding(24)
    }
}
