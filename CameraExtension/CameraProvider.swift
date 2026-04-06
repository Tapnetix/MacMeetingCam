import Foundation
import CoreMediaIO

/// The entry point source for the camera extension.
/// Creates and owns the CameraDevice which in turn owns the CameraStream.
final class CameraProvider: NSObject, CMIOExtensionProviderSource {

    // MARK: - Properties

    private(set) var provider: CMIOExtensionProvider!
    private var device: CameraDevice!

    // MARK: - CMIOExtensionProviderSource

    var availableProperties: Set<CMIOExtensionProperty> {
        [.providerManufacturer]
    }

    // MARK: - Initializer

    init(clientQueue: DispatchQueue?) {
        super.init()
        provider = CMIOExtensionProvider(source: self, clientQueue: clientQueue)
        device = CameraDevice(provider: provider)

        do {
            try provider.addDevice(device.device)
        } catch {
            fatalError("Failed to add device to provider: \(error)")
        }
    }

    // MARK: - Client Connection

    func connect(to client: CMIOExtensionClient) throws {}
    func disconnect(from client: CMIOExtensionClient) {}

    // MARK: - Provider Properties

    func providerProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionProviderProperties {
        let result = CMIOExtensionProviderProperties(dictionary: [:])
        if properties.contains(.providerManufacturer) {
            result.manufacturer = "Tapnetix"
        }
        return result
    }

    func setProviderProperties(_ providerProperties: CMIOExtensionProviderProperties) throws {
        // Read-only provider; ignore property changes from clients.
    }
}
