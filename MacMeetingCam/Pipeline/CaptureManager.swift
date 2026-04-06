import AVFoundation
import Combine

// MARK: - Camera Models

struct CameraInfo: Equatable, Identifiable {
    let id: String
    let name: String
    let formats: [CameraFormat]
}

struct CameraFormat: Equatable {
    let width: Int
    let height: Int
    let frameRates: [Int]
}

// MARK: - Camera Discovery Protocol

protocol CameraDiscovery {
    func availableCameras() -> [CameraInfo]
}

// MARK: - AVFoundation Implementation

final class AVCameraDiscovery: CameraDiscovery {
    func availableCameras() -> [CameraInfo] {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        ).devices

        return devices.map { device in
            let formats = device.formats.compactMap { format -> CameraFormat? in
                let desc = format.formatDescription
                let dims = CMVideoFormatDescriptionGetDimensions(desc)
                let rates = format.videoSupportedFrameRateRanges.map { Int($0.maxFrameRate) }
                return CameraFormat(width: Int(dims.width), height: Int(dims.height), frameRates: rates)
            }
            return CameraInfo(id: device.uniqueID, name: device.localizedName, formats: formats)
        }
    }
}

// MARK: - Mock for Testing

final class MockCameraDiscovery: CameraDiscovery {
    var cameras: [CameraInfo] = []
    func availableCameras() -> [CameraInfo] { cameras }
}

// MARK: - Capture Manager Errors

enum CaptureManagerError: Error, Equatable {
    case cameraNotFound(id: String)
    case configurationFailed(description: String)
}

// MARK: - CaptureManager

final class CaptureManager: ObservableObject {
    enum State: Equatable { case idle, running, disconnected }

    @Published private(set) var state: State = .idle
    @Published private(set) var availableCameras: [CameraInfo] = []

    private let discovery: CameraDiscovery
    private var selectedCameraID: String?
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?

    var onFrame: ((CVPixelBuffer, CMTime) -> Void)?

    init(discovery: CameraDiscovery = AVCameraDiscovery()) {
        self.discovery = discovery
    }

    func refreshCameras() {
        availableCameras = discovery.availableCameras()
    }

    func selectCamera(id: String, width: Int, height: Int, framerate: Int) throws {
        guard availableCameras.contains(where: { $0.id == id }) else {
            throw CaptureManagerError.cameraNotFound(id: id)
        }
        selectedCameraID = id
    }

    func startCapture() {
        guard selectedCameraID != nil else { return }
        state = .running
    }

    func stopCapture() {
        captureSession?.stopRunning()
        captureSession = nil
        videoOutput = nil
        selectedCameraID = nil
        state = .idle
    }
}
