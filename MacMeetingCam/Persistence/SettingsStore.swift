import Foundation

final class SettingsStore {

    private let defaults: UserDefaults

    // MARK: - Keys

    private enum Key: String {
        case blurIntensity
        case edgeSoftness
        case bufferDuration
        case crossfadeDuration
        case resumeTransition
        case backgroundMode
        case backgroundEffectEnabled
        case bufferEnabled
        case launchAtLogin
        case showInMenubar
        case showInDock
        case autoCheckUpdates
        case segmentationQuality
        case selectedCameraID
    }

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        registerDefaults()
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            Key.blurIntensity.rawValue: AppConstants.Defaults.blurIntensity,
            Key.edgeSoftness.rawValue: AppConstants.Defaults.edgeSoftness,
            Key.bufferDuration.rawValue: AppConstants.Defaults.bufferDuration,
            Key.crossfadeDuration.rawValue: AppConstants.Defaults.crossfadeDuration,
            Key.resumeTransition.rawValue: AppConstants.Defaults.resumeTransition,
            Key.backgroundMode.rawValue: BackgroundMode.blur.rawValue,
            Key.backgroundEffectEnabled.rawValue: false,
            Key.bufferEnabled.rawValue: true,
            Key.launchAtLogin.rawValue: true,
            Key.showInMenubar.rawValue: true,
            Key.showInDock.rawValue: false,
            Key.autoCheckUpdates.rawValue: true,
            Key.segmentationQuality.rawValue: SegmentationQuality.balanced.rawValue,
        ])
    }

    // MARK: - Double Properties (with clamping)

    var blurIntensity: Double {
        get { defaults.double(forKey: Key.blurIntensity.rawValue) }
        set { defaults.set(newValue.clamped(to: 0...1), forKey: Key.blurIntensity.rawValue) }
    }

    var edgeSoftness: Double {
        get { defaults.double(forKey: Key.edgeSoftness.rawValue) }
        set { defaults.set(newValue.clamped(to: 0...1), forKey: Key.edgeSoftness.rawValue) }
    }

    var bufferDuration: TimeInterval {
        get { defaults.double(forKey: Key.bufferDuration.rawValue) }
        set {
            let clamped = newValue.clamped(
                to: AppConstants.Defaults.minBufferDuration...AppConstants.Defaults.maxBufferDuration
            )
            defaults.set(clamped, forKey: Key.bufferDuration.rawValue)
        }
    }

    var crossfadeDuration: TimeInterval {
        get { defaults.double(forKey: Key.crossfadeDuration.rawValue) }
        set {
            let clamped = newValue.clamped(
                to: AppConstants.Defaults.minCrossfadeDuration...AppConstants.Defaults.maxCrossfadeDuration
            )
            defaults.set(clamped, forKey: Key.crossfadeDuration.rawValue)
        }
    }

    var resumeTransition: TimeInterval {
        get { defaults.double(forKey: Key.resumeTransition.rawValue) }
        set {
            let clamped = newValue.clamped(
                to: AppConstants.Defaults.minResumeTransition...AppConstants.Defaults.maxResumeTransition
            )
            defaults.set(clamped, forKey: Key.resumeTransition.rawValue)
        }
    }

    // MARK: - Enum Properties

    var backgroundMode: BackgroundMode {
        get {
            let raw = defaults.string(forKey: Key.backgroundMode.rawValue) ?? BackgroundMode.blur.rawValue
            return BackgroundMode(rawValue: raw) ?? .blur
        }
        set { defaults.set(newValue.rawValue, forKey: Key.backgroundMode.rawValue) }
    }

    var segmentationQuality: SegmentationQuality {
        get {
            let raw = defaults.string(forKey: Key.segmentationQuality.rawValue) ?? SegmentationQuality.balanced.rawValue
            return SegmentationQuality(rawValue: raw) ?? .balanced
        }
        set { defaults.set(newValue.rawValue, forKey: Key.segmentationQuality.rawValue) }
    }

    // MARK: - Bool Properties

    var backgroundEffectEnabled: Bool {
        get { defaults.bool(forKey: Key.backgroundEffectEnabled.rawValue) }
        set { defaults.set(newValue, forKey: Key.backgroundEffectEnabled.rawValue) }
    }

    var bufferEnabled: Bool {
        get { defaults.bool(forKey: Key.bufferEnabled.rawValue) }
        set { defaults.set(newValue, forKey: Key.bufferEnabled.rawValue) }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: Key.launchAtLogin.rawValue) }
        set { defaults.set(newValue, forKey: Key.launchAtLogin.rawValue) }
    }

    var showInMenubar: Bool {
        get { defaults.bool(forKey: Key.showInMenubar.rawValue) }
        set { defaults.set(newValue, forKey: Key.showInMenubar.rawValue) }
    }

    var showInDock: Bool {
        get { defaults.bool(forKey: Key.showInDock.rawValue) }
        set { defaults.set(newValue, forKey: Key.showInDock.rawValue) }
    }

    var autoCheckUpdates: Bool {
        get { defaults.bool(forKey: Key.autoCheckUpdates.rawValue) }
        set { defaults.set(newValue, forKey: Key.autoCheckUpdates.rawValue) }
    }

    // MARK: - Optional String Properties

    var selectedCameraID: String? {
        get { defaults.string(forKey: Key.selectedCameraID.rawValue) }
        set { defaults.set(newValue, forKey: Key.selectedCameraID.rawValue) }
    }
}

// MARK: - Comparable Clamping Extension

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
