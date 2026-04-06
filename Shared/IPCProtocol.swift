import Foundation

enum IPCMessage: Codable, Equatable {
    case frameReady(surfaceID: UInt32, width: Int, height: Int, timestamp: Double)
    case startStreaming(width: Int, height: Int, framerate: Int)
    case stopStreaming
    case resolutionChanged(width: Int, height: Int)
}

enum IPCResponse: Codable, Equatable {
    case streamingStarted
    case streamingStopped
    case clientConnected(bundleIdentifier: String)
    case clientDisconnected
    case error(description: String)
}
