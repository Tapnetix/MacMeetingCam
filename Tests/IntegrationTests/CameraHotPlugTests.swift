import XCTest
@testable import MacMeetingCam

final class CameraHotPlugTests: XCTestCase {

    func testCameraAppearsInList() {
        let discovery = MockCameraDiscovery()
        let manager = CaptureManager(discovery: discovery)

        discovery.cameras = [
            CameraInfo(id: "cam1", name: "FaceTime HD", formats: [
                CameraFormat(width: 1920, height: 1080, frameRates: [30])
            ])
        ]

        manager.refreshCameras()
        XCTAssertEqual(manager.availableCameras.count, 1)
        XCTAssertEqual(manager.availableCameras.first?.name, "FaceTime HD")
    }

    func testCameraDisappearsFromList() {
        let discovery = MockCameraDiscovery()
        let manager = CaptureManager(discovery: discovery)

        discovery.cameras = [
            CameraInfo(id: "cam1", name: "FaceTime HD", formats: [])
        ]
        manager.refreshCameras()
        XCTAssertEqual(manager.availableCameras.count, 1)

        discovery.cameras = []
        manager.refreshCameras()
        XCTAssertEqual(manager.availableCameras.count, 0)
    }

    func testMultipleCamerasDetected() {
        let discovery = MockCameraDiscovery()
        let manager = CaptureManager(discovery: discovery)

        discovery.cameras = [
            CameraInfo(id: "cam1", name: "FaceTime HD", formats: []),
            CameraInfo(id: "cam2", name: "USB Webcam", formats: [])
        ]

        manager.refreshCameras()
        XCTAssertEqual(manager.availableCameras.count, 2)
    }
}
