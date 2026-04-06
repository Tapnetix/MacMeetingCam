import Foundation
import Combine

// MARK: - Enums

enum PipelineMode: Equatable {
    case live, frozen, looping
}

enum BackgroundMode: String, Equatable, CaseIterable {
    case blur, remove, replace
}

enum SegmentationQuality: String, Equatable, CaseIterable {
    case fast, balanced, accurate
}

// MARK: - AppState

@MainActor
final class AppState: ObservableObject {

    // MARK: - Pipeline Mode

    @Published private(set) var pipelineMode: PipelineMode = .live

    // MARK: - Background Settings

    @Published var backgroundEffectEnabled: Bool = false {
        didSet { settingsStore?.backgroundEffectEnabled = backgroundEffectEnabled }
    }

    @Published var backgroundMode: BackgroundMode = .blur {
        didSet {
            if pipelineMode != .live {
                hasDeferredChanges = true
            }
            settingsStore?.backgroundMode = backgroundMode
        }
    }

    @Published var blurIntensity: Double = AppConstants.Defaults.blurIntensity {
        didSet {
            if pipelineMode != .live {
                hasDeferredChanges = true
            }
            settingsStore?.blurIntensity = blurIntensity
        }
    }

    @Published var edgeSoftness: Double = AppConstants.Defaults.edgeSoftness {
        didSet {
            if pipelineMode != .live {
                hasDeferredChanges = true
            }
            settingsStore?.edgeSoftness = edgeSoftness
        }
    }

    // MARK: - Buffer Settings

    @Published var bufferEnabled: Bool = true {
        didSet { settingsStore?.bufferEnabled = bufferEnabled }
    }

    @Published var bufferDuration: TimeInterval = AppConstants.Defaults.bufferDuration {
        didSet { settingsStore?.bufferDuration = bufferDuration }
    }

    @Published var crossfadeDuration: TimeInterval = AppConstants.Defaults.crossfadeDuration {
        didSet { settingsStore?.crossfadeDuration = crossfadeDuration }
    }

    @Published var resumeTransition: TimeInterval = AppConstants.Defaults.resumeTransition {
        didSet { settingsStore?.resumeTransition = resumeTransition }
    }

    // MARK: - Camera Settings

    @Published var selectedCameraID: String? = nil {
        didSet { settingsStore?.selectedCameraID = selectedCameraID }
    }

    @Published var selectedResolution: String = "1920x1080"
    @Published var selectedFramerate: Int = AppConstants.Defaults.targetFramerate

    // MARK: - Virtual Camera

    @Published var virtualCameraActive: Bool = false
    @Published var activeConsumerBundleIDs: Set<String> = []

    // MARK: - Segmentation

    @Published var segmentationQuality: SegmentationQuality = .balanced {
        didSet { settingsStore?.segmentationQuality = segmentationQuality }
    }

    // MARK: - App Preferences

    @Published var launchAtLogin: Bool = true {
        didSet { settingsStore?.launchAtLogin = launchAtLogin }
    }

    @Published var showInMenubar: Bool = true {
        didSet { settingsStore?.showInMenubar = showInMenubar }
    }

    @Published var showInDock: Bool = false {
        didSet { settingsStore?.showInDock = showInDock }
    }

    @Published var autoCheckUpdates: Bool = true {
        didSet { settingsStore?.autoCheckUpdates = autoCheckUpdates }
    }

    // MARK: - Background Images

    @Published var backgroundImagePaths: [String] = []
    @Published var selectedBackgroundImagePath: String? = nil

    // MARK: - Deferred Changes

    @Published private(set) var hasDeferredChanges: Bool = false

    // MARK: - Computed

    var hasActiveConsumers: Bool {
        !activeConsumerBundleIDs.isEmpty
    }

    // MARK: - Private

    private let settingsStore: SettingsStore?

    // MARK: - Init

    init(settingsStore: SettingsStore? = nil) {
        self.settingsStore = settingsStore
        if let store = settingsStore {
            loadFromStore(store)
        }
    }

    private func loadFromStore(_ store: SettingsStore) {
        blurIntensity = store.blurIntensity
        edgeSoftness = store.edgeSoftness
        bufferDuration = store.bufferDuration
        crossfadeDuration = store.crossfadeDuration
        resumeTransition = store.resumeTransition
        backgroundMode = store.backgroundMode
        backgroundEffectEnabled = store.backgroundEffectEnabled
        bufferEnabled = store.bufferEnabled
        launchAtLogin = store.launchAtLogin
        showInMenubar = store.showInMenubar
        showInDock = store.showInDock
        autoCheckUpdates = store.autoCheckUpdates
        segmentationQuality = store.segmentationQuality
        selectedCameraID = store.selectedCameraID
    }

    // MARK: - Pipeline Mode Transitions

    func toggleFreeze() {
        switch pipelineMode {
        case .live:
            pipelineMode = .frozen
        case .frozen:
            pipelineMode = .live
            hasDeferredChanges = false
        case .looping:
            pipelineMode = .frozen
        }
    }

    func toggleLoop() {
        switch pipelineMode {
        case .live:
            pipelineMode = .looping
        case .looping:
            pipelineMode = .live
            hasDeferredChanges = false
        case .frozen:
            pipelineMode = .looping
        }
    }

    // MARK: - Background Effect

    func toggleBackgroundEffect() {
        backgroundEffectEnabled.toggle()
    }
}
