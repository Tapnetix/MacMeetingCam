import XCTest
@testable import MacMeetingCam

final class BackgroundImageStoreTests: XCTestCase {

    private var tempDir: URL!
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("BackgroundImageStoreTests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        suiteName = "test.backgroundimagestore.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeStore(defaults: UserDefaults? = nil) -> BackgroundImageStore {
        BackgroundImageStore(defaults: defaults ?? self.defaults)
    }

    private func createTempImage(named name: String) -> String {
        let path = tempDir.appendingPathComponent(name).path
        let data = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
                         0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
                         0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
                         0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
                         0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,
                         0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
                         0x00, 0x00, 0x02, 0x00, 0x01, 0xE2, 0x21, 0xBC,
                         0x33, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
                         0x44, 0xAE, 0x42, 0x60, 0x82])
        FileManager.default.createFile(atPath: path, contents: data)
        return path
    }

    // MARK: - Tests

    func testInitiallyEmpty() {
        let store = makeStore()
        XCTAssertTrue(store.imagePaths.isEmpty)
        XCTAssertNil(store.selectedImagePath)
    }

    func testAddImage() {
        let store = makeStore()
        let path = createTempImage(named: "test1.png")

        store.addImage(at: path)

        XCTAssertEqual(store.imagePaths.count, 1)
        XCTAssertEqual(store.imagePaths.first, path)
    }

    func testAddMultipleImages() {
        let store = makeStore()
        let path1 = createTempImage(named: "img1.png")
        let path2 = createTempImage(named: "img2.png")
        let path3 = createTempImage(named: "img3.png")

        store.addImage(at: path1)
        store.addImage(at: path2)
        store.addImage(at: path3)

        XCTAssertEqual(store.imagePaths.count, 3)
        XCTAssertEqual(store.imagePaths, [path1, path2, path3])
    }

    func testAddDuplicateImageIsIgnored() {
        let store = makeStore()
        let path = createTempImage(named: "dup.png")

        store.addImage(at: path)
        store.addImage(at: path)

        XCTAssertEqual(store.imagePaths.count, 1)
    }

    func testRemoveImage() {
        let store = makeStore()
        let path1 = createTempImage(named: "r1.png")
        let path2 = createTempImage(named: "r2.png")

        store.addImage(at: path1)
        store.addImage(at: path2)
        store.removeImage(at: path1)

        XCTAssertEqual(store.imagePaths.count, 1)
        XCTAssertEqual(store.imagePaths.first, path2)
    }

    func testRemoveSelectedImageClearsSelection() {
        let store = makeStore()
        let path = createTempImage(named: "sel.png")

        store.addImage(at: path)
        store.selectedImagePath = path
        XCTAssertEqual(store.selectedImagePath, path)

        store.removeImage(at: path)
        XCTAssertNil(store.selectedImagePath)
    }

    func testPersistsAcrossInstances() {
        let path1 = createTempImage(named: "persist1.png")
        let path2 = createTempImage(named: "persist2.png")

        let store1 = makeStore()
        store1.addImage(at: path1)
        store1.addImage(at: path2)
        store1.selectedImagePath = path2

        // Create a new store with the same defaults
        let store2 = makeStore()
        XCTAssertEqual(store2.imagePaths.count, 2)
        XCTAssertEqual(store2.imagePaths, [path1, path2])
        XCTAssertEqual(store2.selectedImagePath, path2)
    }

    func testValidateRemovesDeletedFiles() {
        let store = makeStore()
        let path1 = createTempImage(named: "valid.png")
        let path2 = createTempImage(named: "willdelete.png")

        store.addImage(at: path1)
        store.addImage(at: path2)

        // Delete one file
        try! FileManager.default.removeItem(atPath: path2)

        let removed = store.validateAndCleanup()

        XCTAssertEqual(removed, [path2])
        XCTAssertEqual(store.imagePaths.count, 1)
        XCTAssertEqual(store.imagePaths.first, path1)
    }

    func testSelectedImageFallsBackWhenDeleted() {
        let store = makeStore()
        let path = createTempImage(named: "fallback.png")

        store.addImage(at: path)
        store.selectedImagePath = path

        // Delete the file
        try! FileManager.default.removeItem(atPath: path)

        let removed = store.validateAndCleanup()

        XCTAssertEqual(removed, [path])
        XCTAssertNil(store.selectedImagePath)
    }

    func testImageExistsAtPath() {
        let store = makeStore()
        let path = createTempImage(named: "exists.png")

        XCTAssertTrue(store.imageExists(at: path))
        XCTAssertFalse(store.imageExists(at: "/nonexistent/path/image.png"))
    }

    func testAddNonexistentFileIsIgnored() {
        let store = makeStore()

        store.addImage(at: "/nonexistent/path/image.png")

        XCTAssertTrue(store.imagePaths.isEmpty)
    }
}
