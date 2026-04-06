import Foundation
import CoreMediaIO

/// Represents the virtual camera device. Owns the CameraStream.
final class CameraDevice: NSObject, CMIOExtensionDeviceSource {

    // MARK: - Properties

    private(set) var device: CMIOExtensionDevice!
    private(set) var stream: CameraStream!

    // MARK: - CMIOExtensionDeviceSource

    var availableProperties: Set<CMIOExtensionProperty> {
        [.deviceModel, .deviceTransportType]
    }

    // MARK: - Initializer

    init(provider: CMIOExtensionProvider) {
        super.init()
        device = CMIOExtensionDevice(
            localizedName: AppConstants.virtualCameraName,
            deviceID: UUID(),
            legacyDeviceID: nil,
            source: self
        )
        stream = CameraStream(device: device)
        do {
            try device.addStream(stream.stream)
        } catch {
            fatalError("Failed to add stream: \(error)")
        }
    }

    // MARK: - Client Connection

    func connect(to client: CMIOExtensionClient) throws {}
    func disconnect(from client: CMIOExtensionClient) {}

    // MARK: - Device Properties

    func deviceProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionDeviceProperties {
        let result = CMIOExtensionDeviceProperties(dictionary: [:])
        if properties.contains(.deviceModel) {
            result.model = "MacMeetingCam Virtual Camera"
        }
        if properties.contains(.deviceTransportType) {
            result.transportType = 0  // virtual device
        }
        return result
    }

    func setDeviceProperties(_ deviceProperties: CMIOExtensionDeviceProperties) throws {
        // Read-only device; ignore property changes from clients.
    }
}
