import Foundation

final class BackgroundImageStore {

    private let defaults: UserDefaults
    private let fileManager: FileManager

    // MARK: - Keys

    private enum Key: String {
        case imagePaths = "backgroundImagePaths"
        case selectedImagePath = "selectedBackgroundImagePath"
    }

    // MARK: - Published Properties

    private(set) var imagePaths: [String] {
        get { defaults.stringArray(forKey: Key.imagePaths.rawValue) ?? [] }
        set { defaults.set(newValue, forKey: Key.imagePaths.rawValue) }
    }

    var selectedImagePath: String? {
        get { defaults.string(forKey: Key.selectedImagePath.rawValue) }
        set { defaults.set(newValue, forKey: Key.selectedImagePath.rawValue) }
    }

    // MARK: - Init

    init(defaults: UserDefaults = .standard, fileManager: FileManager = .default) {
        self.defaults = defaults
        self.fileManager = fileManager
    }

    // MARK: - Methods

    func addImage(at path: String) {
        guard imageExists(at: path) else { return }
        guard !imagePaths.contains(path) else { return }
        imagePaths.append(path)
    }

    func removeImage(at path: String) {
        imagePaths.removeAll { $0 == path }
        if selectedImagePath == path {
            selectedImagePath = nil
        }
    }

    func imageExists(at path: String) -> Bool {
        fileManager.fileExists(atPath: path)
    }

    @discardableResult
    func validateAndCleanup() -> [String] {
        let current = imagePaths
        var removed: [String] = []
        var remaining: [String] = []

        for path in current {
            if imageExists(at: path) {
                remaining.append(path)
            } else {
                removed.append(path)
            }
        }

        if !removed.isEmpty {
            imagePaths = remaining
            if let selected = selectedImagePath, removed.contains(selected) {
                selectedImagePath = nil
            }
        }

        return removed
    }
}
