import AppKit
import SwiftUI

final class FloatingPreviewPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 250),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isMovableByWindowBackground = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.minSize = NSSize(width: 200, height: 150)
    }
}

struct FloatingPreviewView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Preview area
            RoundedRectangle(cornerRadius: 0)
                .fill(Color.black)
                .aspectRatio(16/9, contentMode: .fit)
                .overlay(
                    Text("Preview")
                        .foregroundColor(.gray)
                        .font(.caption)
                )
                .accessibilityIdentifier("floatingPreview")

            // Controls bar
            HStack {
                // Status
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(statusText)
                        .font(.system(size: 11))
                        .foregroundColor(statusColor)
                }

                Spacer()

                // Compact toggle buttons
                HStack(spacing: 4) {
                    CompactToggleButton(icon: "photo", isActive: appState.backgroundEffectEnabled) {
                        appState.toggleBackgroundEffect()
                    }
                    .accessibilityIdentifier("floatingBgToggle")

                    CompactToggleButton(icon: "pause", isActive: appState.pipelineMode == .frozen) {
                        appState.toggleFreeze()
                    }
                    .accessibilityIdentifier("floatingFreezeToggle")

                    CompactToggleButton(icon: "arrow.2.squarepath", isActive: appState.pipelineMode == .looping) {
                        appState.toggleLoop()
                    }
                    .accessibilityIdentifier("floatingLoopToggle")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.6))
        }
    }

    private var statusColor: Color {
        switch appState.pipelineMode {
        case .live: return .green
        case .frozen: return .yellow
        case .looping: return .red
        }
    }

    private var statusText: String {
        switch appState.pipelineMode {
        case .live: return "Live"
        case .frozen: return "Frozen"
        case .looping: return "Looping"
        }
    }
}

struct CompactToggleButton: View {
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .frame(width: 28, height: 28)
                .background(isActive ? Color.accentColor : Color.gray.opacity(0.3))
                .foregroundColor(isActive ? .white : .secondary)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}
