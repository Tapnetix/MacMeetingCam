import SwiftUI

struct CameraTabView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Preview area (placeholder rectangle)
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black)
                .aspectRatio(16/9, contentMode: .fit)
                .overlay(
                    Text("Camera Preview")
                        .foregroundColor(.gray)
                )
                .accessibilityIdentifier("cameraPreview")

            // Camera source picker
            HStack {
                Text("Source Camera").frame(width: 130, alignment: .trailing)
                Picker("", selection: $appState.selectedCameraID) {
                    Text("No Camera").tag(String?.none)
                }
                .accessibilityIdentifier("cameraSourcePicker")
            }

            // Resolution picker
            HStack {
                Text("Resolution").frame(width: 130, alignment: .trailing)
                Picker("", selection: $appState.selectedResolution) {
                    Text("1920 \u{00d7} 1080").tag("1920x1080")
                    Text("1280 \u{00d7} 720").tag("1280x720")
                }
                .accessibilityIdentifier("resolutionPicker")
            }

            // Framerate picker
            HStack {
                Text("Framerate").frame(width: 130, alignment: .trailing)
                Picker("", selection: $appState.selectedFramerate) {
                    Text("30 fps").tag(30)
                    Text("24 fps").tag(24)
                }
                .accessibilityIdentifier("frameratePicker")
            }

            Divider()

            // Virtual camera status
            HStack {
                Text("Virtual Camera").frame(width: 130, alignment: .trailing)
                HStack(spacing: 6) {
                    Circle()
                        .fill(appState.virtualCameraActive ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    Text(appState.virtualCameraActive ? "Active \u{2014} \"MacMeetingCam\"" : "Inactive")
                        .font(.callout)
                }
                .accessibilityIdentifier("virtualCameraStatus")
            }

            Spacer()
        }
        .padding(24)
    }
}
