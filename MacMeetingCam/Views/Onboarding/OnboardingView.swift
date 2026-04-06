import SwiftUI

struct OnboardingView: View {
    @State private var currentStep: Int = 0
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            switch currentStep {
            case 0: welcomeStep
            case 1: cameraPermissionStep
            case 2: accessibilityPermissionStep
            case 3: extensionApprovalStep
            case 4: doneStep
            default: doneStep
            }
        }
        .frame(width: 500, height: 400)
        .padding(40)
    }

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            Text("Welcome to MacMeetingCam")
                .font(.title)
                .fontWeight(.bold)
                .accessibilityIdentifier("welcomeTitle")
            Text("Virtual camera with background effects and seamless pause/loop for your meetings.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Spacer()
            Button("Get Started") {
                currentStep = 1
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("getStartedButton")
        }
    }

    private var cameraPermissionStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            Text("Camera Access")
                .font(.title2)
                .fontWeight(.bold)
                .accessibilityIdentifier("cameraAccessTitle")
            Text("MacMeetingCam needs camera access to process your video feed.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Spacer()
            Button("Continue") { currentStep = 2 }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("cameraContinueButton")
        }
    }

    private var accessibilityPermissionStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "keyboard")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            Text("Accessibility Permission")
                .font(.title2)
                .fontWeight(.bold)
                .accessibilityIdentifier("accessibilityTitle")
            Text("Required for global keyboard shortcuts. Open System Settings to grant access.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Spacer()
            Button("Continue") { currentStep = 3 }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("accessibilityContinueButton")
        }
    }

    private var extensionApprovalStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "puzzlepiece.extension.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            Text("Camera Extension")
                .font(.title2)
                .fontWeight(.bold)
                .accessibilityIdentifier("extensionTitle")
            Text("Approve the camera extension in System Settings -> Privacy & Security to enable the virtual camera.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Spacer()
            Button("Continue") { currentStep = 4 }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("extensionContinueButton")
        }
    }

    private var doneStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            Text("You're All Set!")
                .font(.title2)
                .fontWeight(.bold)
                .accessibilityIdentifier("doneTitle")
            Text("MacMeetingCam is ready. Select \"MacMeetingCam\" as your camera in any meeting app.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Spacer()
            Button("Open Settings") {
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("openSettingsButton")
        }
    }
}
