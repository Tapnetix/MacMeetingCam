import Foundation
import KeyboardShortcuts

// Define the shortcut names
extension KeyboardShortcuts.Name {
    static let toggleBackgroundEffect = Self("toggleBackgroundEffect")
    static let toggleFreeze = Self("toggleFreeze")
    static let toggleLoop = Self("toggleLoop")
    static let toggleCamera = Self("toggleCamera")
}

enum HotkeyAction: String, CaseIterable {
    case toggleBackgroundEffect
    case toggleFreeze
    case toggleLoop
    case toggleCamera

    var shortcutName: KeyboardShortcuts.Name {
        switch self {
        case .toggleBackgroundEffect: return .toggleBackgroundEffect
        case .toggleFreeze: return .toggleFreeze
        case .toggleLoop: return .toggleLoop
        case .toggleCamera: return .toggleCamera
        }
    }
}

extension HotkeyAction {
    var displayName: String {
        switch self {
        case .toggleBackgroundEffect: return "Toggle Background Effect"
        case .toggleFreeze: return "Toggle Freeze"
        case .toggleLoop: return "Toggle Loop"
        case .toggleCamera: return "Camera On / Off"
        }
    }
}

final class HotkeyManager: ObservableObject {
    typealias ActionHandler = (HotkeyAction) -> Void

    private var handler: ActionHandler?

    init() {}

    /// Set the handler that will be called when any hotkey is pressed
    func setHandler(_ handler: @escaping ActionHandler) {
        self.handler = handler
        registerAll()
    }

    /// Register keyboard shortcut handlers for all actions
    func registerAll() {
        for action in HotkeyAction.allCases {
            KeyboardShortcuts.onKeyUp(for: action.shortcutName) { [weak self] in
                self?.handler?(action)
            }
        }
    }

    /// Unregister all handlers
    func unregisterAll() {
        for action in HotkeyAction.allCases {
            KeyboardShortcuts.disable(action.shortcutName)
        }
    }

    /// Check if a shortcut is set for an action
    func hasShortcut(for action: HotkeyAction) -> Bool {
        KeyboardShortcuts.getShortcut(for: action.shortcutName) != nil
    }

    /// Reset all shortcuts to defaults
    func restoreDefaults() {
        for action in HotkeyAction.allCases {
            KeyboardShortcuts.reset(action.shortcutName)
        }
    }

    /// Get all actions that have shortcuts set
    func actionsWithShortcuts() -> [HotkeyAction] {
        HotkeyAction.allCases.filter { hasShortcut(for: $0) }
    }
}
