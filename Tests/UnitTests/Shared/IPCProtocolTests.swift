import XCTest
@testable import MacMeetingCam

final class IPCProtocolTests: XCTestCase {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - IPCMessage round-trips

    func testFrameReadyMessageEncodeDecode() throws {
        let original = IPCMessage.frameReady(
            surfaceID: 42,
            width: 1920,
            height: 1080,
            timestamp: 123.456
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(IPCMessage.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testStartStreamingMessageEncodeDecode() throws {
        let original = IPCMessage.startStreaming(
            width: 1280,
            height: 720,
            framerate: 30
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(IPCMessage.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testStopStreamingMessageEncodeDecode() throws {
        let original = IPCMessage.stopStreaming
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(IPCMessage.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testResolutionChangedMessageEncodeDecode() throws {
        let original = IPCMessage.resolutionChanged(
            width: 3840,
            height: 2160
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(IPCMessage.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - IPCResponse round-trips

    func testStreamingStartedResponseEncodeDecode() throws {
        let original = IPCResponse.streamingStarted
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(IPCResponse.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testStreamingStoppedResponseEncodeDecode() throws {
        let original = IPCResponse.streamingStopped
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(IPCResponse.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testClientConnectedResponseEncodeDecode() throws {
        let original = IPCResponse.clientConnected(
            bundleIdentifier: "com.apple.FaceTime"
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(IPCResponse.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testClientDisconnectedResponseEncodeDecode() throws {
        let original = IPCResponse.clientDisconnected
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(IPCResponse.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testErrorResponseEncodeDecode() throws {
        let original = IPCResponse.error(
            description: "Something went wrong"
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(IPCResponse.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}
