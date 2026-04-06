import SwiftUI

struct LoopTabView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Buffer on/off toggle
            Toggle("Enable Rolling Buffer", isOn: $appState.bufferEnabled)
                .accessibilityIdentifier("bufferEnabledToggle")

            // Buffer duration slider
            HStack {
                Text("Buffer Duration").frame(width: 130, alignment: .trailing)
                Slider(
                    value: $appState.bufferDuration,
                    in: AppConstants.Defaults.minBufferDuration...AppConstants.Defaults.maxBufferDuration,
                    step: 1
                )
                .accessibilityIdentifier("bufferDurationSlider")
                Text(String(format: "%.0fs", appState.bufferDuration))
                    .frame(width: 40, alignment: .trailing)
            }

            // Memory estimate info box
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                Text("Estimated memory: \(MemoryEstimator.formattedEstimate(durationSeconds: appState.bufferDuration, width: 1920, height: 1080, fps: appState.selectedFramerate))")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .accessibilityIdentifier("memoryEstimateInfo")

            Divider()

            // Crossfade duration slider
            HStack {
                Text("Crossfade Duration").frame(width: 130, alignment: .trailing)
                Slider(
                    value: $appState.crossfadeDuration,
                    in: AppConstants.Defaults.minCrossfadeDuration...AppConstants.Defaults.maxCrossfadeDuration,
                    step: 0.1
                )
                .accessibilityIdentifier("crossfadeDurationSlider")
                Text(String(format: "%.1fs", appState.crossfadeDuration))
                    .frame(width: 40, alignment: .trailing)
            }

            // Resume transition slider
            HStack {
                Text("Resume Transition").frame(width: 130, alignment: .trailing)
                Slider(
                    value: $appState.resumeTransition,
                    in: AppConstants.Defaults.minResumeTransition...AppConstants.Defaults.maxResumeTransition,
                    step: 0.1
                )
                .accessibilityIdentifier("resumeTransitionSlider")
                Text(String(format: "%.1fs", appState.resumeTransition))
                    .frame(width: 40, alignment: .trailing)
            }

            Divider()

            // Buffer timeline placeholder
            VStack(alignment: .leading, spacing: 8) {
                Text("Buffer Timeline")
                    .font(.headline)

                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 60)
                    .overlay(
                        GeometryReader { geometry in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.accentColor.opacity(0.4))
                                .frame(width: geometry.size.width * 0.3, height: 50)
                                .padding(.leading, 5)
                                .padding(.vertical, 5)
                        }
                    )
                    .accessibilityIdentifier("bufferTimeline")
            }

            Spacer()
        }
        .padding(24)
    }
}
