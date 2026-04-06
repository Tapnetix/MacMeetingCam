import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState

    enum Tab: String, CaseIterable, Identifiable {
        case camera = "Camera"
        case background = "Background"
        case loop = "Loop"
        case hotkeys = "Hotkeys"
        case general = "General"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .camera: return "video"
            case .background: return "photo"
            case .loop: return "arrow.2.squarepath"
            case .hotkeys: return "keyboard"
            case .general: return "gear"
            }
        }
    }

    @State private var selectedTab: Tab = .camera

    var body: some View {
        NavigationSplitView {
            List(Tab.allCases, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 160)
        } detail: {
            switch selectedTab {
            case .camera:
                CameraTabView(appState: appState)
            case .background:
                BackgroundTabView(appState: appState)
            case .loop:
                LoopTabView(appState: appState)
            case .hotkeys:
                HotkeysTabView()
            case .general:
                GeneralTabView(appState: appState)
            }
        }
        .frame(minWidth: 800, minHeight: 520)
    }
}
