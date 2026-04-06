import XCTest
@testable import MacMeetingCam

final class ThumbnailCacheTests: XCTestCase {

    private var tempDir: URL!
    private var cacheDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ThumbnailCacheTests-\(UUID().uuidString)")
        cacheDir = tempDir.appendingPathComponent("cache")
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeCache() -> ThumbnailCache {
        ThumbnailCache(cacheDirectory: cacheDir)
    }

    private func createTestImage(named name: String, size: NSSize) -> String {
        let path = tempDir.appendingPathComponent(name).path
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        let tiff = image.tiffRepresentation!
        let bitmap = NSBitmapImageRep(data: tiff)!
        let png = bitmap.representation(using: .png, properties: [:])!
        try! png.write(to: URL(fileURLWithPath: path))
        return path
    }

    // MARK: - Tests

    func testGeneratesThumbnailForImage() {
        let cache = makeCache()
        let path = createTestImage(named: "source.png", size: NSSize(width: 200, height: 100))
        let targetSize = NSSize(width: 50, height: 50)

        let thumbnail = cache.thumbnail(for: path, targetSize: targetSize)

        XCTAssertNotNil(thumbnail)
        if let thumb = thumbnail {
            XCTAssertLessThanOrEqual(thumb.size.width, targetSize.width)
            XCTAssertLessThanOrEqual(thumb.size.height, targetSize.height)
        }
    }

    func testCacheHitReturnsSameImage() {
        let cache = makeCache()
        let path = createTestImage(named: "cached.png", size: NSSize(width: 100, height: 100))
        let targetSize = NSSize(width: 50, height: 50)

        // Generate thumbnail the first time
        let first = cache.thumbnail(for: path, targetSize: targetSize)
        XCTAssertNotNil(first)

        // Verify cached file exists
        XCTAssertTrue(cache.hasCachedThumbnail(for: path))

        // Generate again — should come from cache
        let second = cache.thumbnail(for: path, targetSize: targetSize)
        XCTAssertNotNil(second)
    }

    func testReturnsNilForNonexistentFile() {
        let cache = makeCache()
        let targetSize = NSSize(width: 50, height: 50)

        let result = cache.thumbnail(for: "/nonexistent/path/image.png", targetSize: targetSize)

        XCTAssertNil(result)
    }

    func testClearRemovesAllCachedThumbnails() {
        let cache = makeCache()
        let path1 = createTestImage(named: "clear1.png", size: NSSize(width: 100, height: 100))
        let path2 = createTestImage(named: "clear2.png", size: NSSize(width: 100, height: 100))
        let targetSize = NSSize(width: 50, height: 50)

        // Generate thumbnails
        _ = cache.thumbnail(for: path1, targetSize: targetSize)
        _ = cache.thumbnail(for: path2, targetSize: targetSize)

        XCTAssertTrue(cache.hasCachedThumbnail(for: path1))
        XCTAssertTrue(cache.hasCachedThumbnail(for: path2))

        cache.clearAll()

        XCTAssertFalse(cache.hasCachedThumbnail(for: path1))
        XCTAssertFalse(cache.hasCachedThumbnail(for: path2))
    }

    func testCleanupRemovesOrphanedThumbnails() {
        let cache = makeCache()
        let path1 = createTestImage(named: "keep.png", size: NSSize(width: 100, height: 100))
        let path2 = createTestImage(named: "orphan.png", size: NSSize(width: 100, height: 100))
        let targetSize = NSSize(width: 50, height: 50)

        // Generate thumbnails for both
        _ = cache.thumbnail(for: path1, targetSize: targetSize)
        _ = cache.thumbnail(for: path2, targetSize: targetSize)

        XCTAssertTrue(cache.hasCachedThumbnail(for: path1))
        XCTAssertTrue(cache.hasCachedThumbnail(for: path2))

        // Cleanup with only path1 as valid — path2 is orphaned
        let removedCount = cache.cleanupOrphaned(validPaths: [path1])

        XCTAssertEqual(removedCount, 1)
        XCTAssertTrue(cache.hasCachedThumbnail(for: path1))
        XCTAssertFalse(cache.hasCachedThumbnail(for: path2))
    }
}
