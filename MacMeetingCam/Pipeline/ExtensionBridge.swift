import Foundation
import CoreVideo
import CoreMedia

// MARK: - Extension Bridge Errors

enum ExtensionBridgeError: Error, Equatable {
    case notConnected
    case sendFailed(description: String)
}

// MARK: - ExtensionBridge

/// The IPC layer between the host app and the Camera Extension.
/// Manages connection state and frame delivery to the virtual camera.
final class ExtensionBridge: ObservableObject {
    enum ConnectionState: Equatable { case disconnected, connecting, connected }

    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var activeConsumers: Set<String> = []

    var hasActiveConsumers: Bool { !activeConsumers.isEmpty }

    // MARK: - Connection Management

    func connect() {
        connectionState = .connecting
        // In a real implementation, this would establish an XPC connection
        // to the Camera Extension. For now, transition to connected.
        connectionState = .connected
    }

    func disconnect() {
        connectionState = .disconnected
        activeConsumers.removeAll()
    }

    // MARK: - Frame Delivery

    /// Sends a processed frame to the Camera Extension for virtual camera output.
    /// - Parameters:
    ///   - pixelBuffer: The frame to send.
    ///   - timestamp: The frame's presentation timestamp.
    /// - Throws: `ExtensionBridgeError.notConnected` if not connected.
    func sendFrame(_ pixelBuffer: CVPixelBuffer, timestamp: CMTime) throws {
        guard connectionState == .connected else {
            throw ExtensionBridgeError.notConnected
        }
        // In a real implementation, this would write the frame to a shared
        // IOSurface and notify the extension via XPC.
    }

    // MARK: - IPC Response Handling

    /// Handles responses received from the Camera Extension via IPC.
    /// - Parameter response: The IPC response to handle.
    func handleResponse(_ response: IPCResponse) {
        switch response {
        case .clientConnected(let bundleIdentifier):
            activeConsumers.insert(bundleIdentifier)
        case .clientDisconnected:
            // When a client disconnects, we don't know which one,
            // so clear all consumers. A real implementation would
            // track individual client sessions.
            activeConsumers.removeAll()
        case .streamingStarted:
            break
        case .streamingStopped:
            break
        case .error:
            break
        }
    }
}
