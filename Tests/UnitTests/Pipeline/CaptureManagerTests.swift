import XCTest
@testable import MacMeetingCam

final class CaptureManagerTests: XCTestCase {

    private var mockDiscovery: MockCameraDiscovery!
    private var captureManager: CaptureManager!

    override func setUp() {
        super.setUp()
        mockDiscovery = MockCameraDiscovery()
        captureManager = CaptureManager(discovery: mockDiscovery)
    }

    override func tearDown() {
        captureManager = nil
        mockDiscovery = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialStateIsIdle() {
        XCTAssertEqual(captureManager.state, .idle)
    }

    // MARK: - Refresh Cameras

    func testRefreshCamerasPopulatesList() {
        let cameras = [
            CameraInfo(
                id: "cam-1",
                name: "FaceTime HD Camera",
                formats: [CameraFormat(width: 1920, height: 1080, frameRates: [24, 30])]
            ),
            CameraInfo(
                id: "cam-2",
                name: "USB Webcam",
                formats: [CameraFormat(width: 1280, height: 720, frameRates: [30, 60])]
            ),
        ]
        mockDiscovery.cameras = cameras

        captureManager.refreshCameras()

        XCTAssertEqual(captureManager.availableCameras.count, 2)
        XCTAssertEqual(captureManager.availableCameras[0].id, "cam-1")
        XCTAssertEqual(captureManager.availableCameras[0].name, "FaceTime HD Camera")
        XCTAssertEqual(captureManager.availableCameras[1].id, "cam-2")
        XCTAssertEqual(captureManager.availableCameras[1].name, "USB Webcam")
    }

    func testRefreshCamerasWithNoCameras() {
        mockDiscovery.cameras = []

        captureManager.refreshCameras()

        XCTAssertTrue(captureManager.availableCameras.isEmpty)
    }

    // MARK: - Select Camera

    func testSelectCameraChangesState() {
        let cameras = [
            CameraInfo(
                id: "cam-1",
                name: "FaceTime HD Camera",
                formats: [CameraFormat(width: 1920, height: 1080, frameRates: [30])]
            ),
        ]
        mockDiscovery.cameras = cameras
        captureManager.refreshCameras()

        XCTAssertNoThrow(try captureManager.selectCamera(id: "cam-1", width: 1920, height: 1080, framerate: 30))

        // After selecting a camera, starting capture should transition to running
        captureManager.startCapture()
        XCTAssertEqual(captureManager.state, .running)
    }

    func testSelectCameraThrowsForUnknownCamera() {
        mockDiscovery.cameras = []
        captureManager.refreshCameras()

        XCTAssertThrowsError(
            try captureManager.selectCamera(id: "nonexistent", width: 1920, height: 1080, framerate: 30)
        ) { error in
            XCTAssertEqual(error as? CaptureManagerError, .cameraNotFound(id: "nonexistent"))
        }
    }

    // MARK: - Stop Capture

    func testStopCaptureResetsState() {
        let cameras = [
            CameraInfo(
                id: "cam-1",
                name: "FaceTime HD Camera",
                formats: [CameraFormat(width: 1920, height: 1080, frameRates: [30])]
            ),
        ]
        mockDiscovery.cameras = cameras
        captureManager.refreshCameras()
        try! captureManager.selectCamera(id: "cam-1", width: 1920, height: 1080, framerate: 30)
        captureManager.startCapture()
        XCTAssertEqual(captureManager.state, .running)

        captureManager.stopCapture()

        XCTAssertEqual(captureManager.state, .idle)
    }
}
