import Foundation
import CoreMediaIO

// Placeholder — will be implemented in Phase 4

// Minimal CMIOExtension provider to satisfy linker
final class CameraExtensionProvider: NSObject, CMIOExtensionProviderSource {
    private(set) var provider: CMIOExtensionProvider!
    var availableProperties: Set<CMIOExtensionProperty> { [] }

    init(clientQueue: DispatchQueue?) {
        super.init()
        provider = CMIOExtensionProvider(source: self, clientQueue: clientQueue)
    }

    func connect(to client: CMIOExtensionClient) throws {}
    func disconnect(from client: CMIOExtensionClient) {}

    func providerProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionProviderProperties {
        CMIOExtensionProviderProperties(dictionary: [:])
    }

    func setProviderProperties(_ providerProperties: CMIOExtensionProviderProperties) throws {}
}

// Entry point
let providerSource = CameraExtensionProvider(clientQueue: nil)
CMIOExtensionProvider.startService(provider: providerSource.provider)
