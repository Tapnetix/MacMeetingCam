import SwiftUI

@main
struct MacMeetingCamApp: App {
    @StateObject private var appState = AppState()
    @State private var showOnboarding: Bool

    init() {
        let args = ProcessInfo.processInfo.arguments
        let skipOnboarding = args.contains("--skip-onboarding")
        let resetSettings = args.contains("--reset-settings")

        if resetSettings {
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
        }

        let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        _showOnboarding = State(initialValue: !hasCompleted && !skipOnboarding)
    }

    var body: some Scene {
        WindowGroup {
            if showOnboarding {
                OnboardingView {
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    showOnboarding = false
                }
            } else {
                SettingsView(appState: appState)
            }
        }
        .defaultSize(width: 800, height: 520)
    }
}
