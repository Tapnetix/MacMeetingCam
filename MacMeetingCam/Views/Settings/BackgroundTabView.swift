import SwiftUI

struct BackgroundTabView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Background effect toggle
            Toggle("Enable Background Effect", isOn: $appState.backgroundEffectEnabled)
                .accessibilityIdentifier("backgroundEffectToggle")

            // Mode selector (segmented)
            Picker("Mode", selection: $appState.backgroundMode) {
                Text("Blur").tag(BackgroundMode.blur)
                Text("Remove").tag(BackgroundMode.remove)
                Text("Replace").tag(BackgroundMode.replace)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("backgroundModePicker")

            // Preview area
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black)
                .aspectRatio(16/9, contentMode: .fit)
                .overlay(
                    Text("Background Preview")
                        .foregroundColor(.gray)
                )
                .accessibilityIdentifier("backgroundPreview")

            // Blur intensity slider (only in blur mode)
            if appState.backgroundMode == .blur {
                HStack {
                    Text("Blur Intensity").frame(width: 130, alignment: .trailing)
                    Slider(value: $appState.blurIntensity, in: 0...1)
                        .accessibilityIdentifier("blurIntensitySlider")
                    Text(String(format: "%.0f%%", appState.blurIntensity * 100))
                        .frame(width: 40, alignment: .trailing)
                }
            }

            // Edge softness slider
            HStack {
                Text("Edge Softness").frame(width: 130, alignment: .trailing)
                Slider(value: $appState.edgeSoftness, in: 0...1)
                    .accessibilityIdentifier("edgeSoftnessSlider")
                Text(String(format: "%.0f%%", appState.edgeSoftness * 100))
                    .frame(width: 40, alignment: .trailing)
            }

            // Deferred changes label
            if appState.hasDeferredChanges {
                Text("Changes apply when live")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .accessibilityIdentifier("deferredChangesLabel")
            }

            // Background image grid (only in replace mode)
            if appState.backgroundMode == .replace {
                Divider()

                Text("Background Images")
                    .font(.headline)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Add button
                        Button(action: {}) {
                            VStack {
                                Image(systemName: "plus")
                                    .font(.title2)
                                Text("Add")
                                    .font(.caption)
                            }
                            .frame(width: 80, height: 60)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("addBackgroundImageButton")

                        // Image thumbnails
                        ForEach(appState.backgroundImagePaths, id: \.self) { path in
                            RoundedRectangle(cornerRadius: 8)
                                .fill(appState.selectedBackgroundImagePath == path ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.2))
                                .frame(width: 80, height: 60)
                                .overlay(
                                    Text(URL(fileURLWithPath: path).lastPathComponent)
                                        .font(.caption2)
                                        .lineLimit(1)
                                )
                                .onTapGesture {
                                    appState.selectedBackgroundImagePath = path
                                }
                                .accessibilityIdentifier("backgroundImage_\(path)")
                        }
                    }
                }
                .accessibilityIdentifier("backgroundImageGrid")
            }

            Spacer()
        }
        .padding(24)
    }
}
