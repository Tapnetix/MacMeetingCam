import Foundation
import CoreMediaIO

let providerSource = CameraProvider(clientQueue: nil)
CMIOExtensionProvider.startService(provider: providerSource.provider)
