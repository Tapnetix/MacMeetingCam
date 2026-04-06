import AppKit
import CryptoKit
import Foundation

final class ThumbnailCache {

    private let cacheDirectory: URL
    private let fileManager: FileManager

    // MARK: - Init

    init(cacheDirectory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager

        if let cacheDirectory {
            self.cacheDirectory = cacheDirectory
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.cacheDirectory = appSupport
                .appendingPathComponent("MacMeetingCam")
                .appendingPathComponent("Thumbnails")
        }

        try? fileManager.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Methods

    func thumbnail(for imagePath: String, targetSize: NSSize) -> NSImage? {
        guard fileManager.fileExists(atPath: imagePath) else { return nil }

        let cacheFile = cacheFileURL(for: imagePath)

        // Return cached thumbnail if it exists
        if fileManager.fileExists(atPath: cacheFile.path) {
            return NSImage(contentsOf: cacheFile)
        }

        // Generate thumbnail
        guard let sourceImage = NSImage(contentsOfFile: imagePath) else { return nil }

        let thumbnail = resizeImageToFit(sourceImage, targetSize: targetSize)

        // Save to cache
        if let tiff = thumbnail.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            try? pngData.write(to: cacheFile)
        }

        return thumbnail
    }

    func hasCachedThumbnail(for imagePath: String) -> Bool {
        let cacheFile = cacheFileURL(for: imagePath)
        return fileManager.fileExists(atPath: cacheFile.path)
    }

    func clearAll() {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil
        ) else { return }

        for file in contents {
            try? fileManager.removeItem(at: file)
        }
    }

    @discardableResult
    func cleanupOrphaned(validPaths: [String]) -> Int {
        let validHashes = Set(validPaths.map { cacheKey(for: $0) })

        guard let contents = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil
        ) else { return 0 }

        var removedCount = 0
        for file in contents where file.pathExtension == "png" {
            let hash = file.deletingPathExtension().lastPathComponent
            if !validHashes.contains(hash) {
                try? fileManager.removeItem(at: file)
                removedCount += 1
            }
        }

        return removedCount
    }

    // MARK: - Private Helpers

    private func cacheKey(for imagePath: String) -> String {
        let data = Data(imagePath.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func cacheFileURL(for imagePath: String) -> URL {
        cacheDirectory.appendingPathComponent("\(cacheKey(for: imagePath)).png")
    }

    private func resizeImageToFit(_ image: NSImage, targetSize: NSSize) -> NSImage {
        let originalSize = image.size
        guard originalSize.width > 0, originalSize.height > 0 else { return image }

        let widthRatio = targetSize.width / originalSize.width
        let heightRatio = targetSize.height / originalSize.height
        let scale = min(widthRatio, heightRatio, 1.0) // Don't upscale

        let newSize = NSSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )

        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: originalSize),
            operation: .copy,
            fraction: 1.0
        )
        thumbnail.unlockFocus()

        return thumbnail
    }
}
