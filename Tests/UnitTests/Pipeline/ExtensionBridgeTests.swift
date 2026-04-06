import XCTest
import CoreMedia
import CoreVideo
@testable import MacMeetingCam

final class ExtensionBridgeTests: XCTestCase {

    private var bridge: ExtensionBridge!

    override func setUp() {
        super.setUp()
        bridge = ExtensionBridge()
    }

    override func tearDown() {
        bridge = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialStateIsDisconnected() {
        XCTAssertEqual(bridge.connectionState, .disconnected)
        XCTAssertTrue(bridge.activeConsumers.isEmpty)
        XCTAssertFalse(bridge.hasActiveConsumers)
    }

    // MARK: - Connection Management

    func testConnectChangesState() {
        bridge.connect()

        XCTAssertEqual(bridge.connectionState, .connected)
    }

    func testDisconnectChangesState() {
        bridge.connect()
        XCTAssertEqual(bridge.connectionState, .connected)

        bridge.disconnect()

        XCTAssertEqual(bridge.connectionState, .disconnected)
    }

    // MARK: - Consumer Tracking

    func testHandleClientConnectedAddsConsumer() {
        bridge.connect()

        bridge.handleResponse(.clientConnected(bundleIdentifier: "com.zoom.us"))

        XCTAssertTrue(bridge.activeConsumers.contains("com.zoom.us"))
        XCTAssertEqual(bridge.activeConsumers.count, 1)
    }

    func testHandleClientDisconnectedRemovesConsumer() {
        bridge.connect()
        bridge.handleResponse(.clientConnected(bundleIdentifier: "com.zoom.us"))
        XCTAssertEqual(bridge.activeConsumers.count, 1)

        bridge.handleResponse(.clientDisconnected)

        XCTAssertTrue(bridge.activeConsumers.isEmpty)
    }

    func testHasActiveConsumers() {
        XCTAssertFalse(bridge.hasActiveConsumers)

        bridge.connect()
        bridge.handleResponse(.clientConnected(bundleIdentifier: "com.zoom.us"))

        XCTAssertTrue(bridge.hasActiveConsumers)

        bridge.handleResponse(.clientDisconnected)

        XCTAssertFalse(bridge.hasActiveConsumers)
    }

    // MARK: - Frame Sending

    func testSendFrameThrowsWhenDisconnected() {
        let frame = SyntheticFrameGenerator.solidColor(
            width: TestConstants.smallWidth,
            height: TestConstants.smallHeight,
            red: 100, green: 150, blue: 200
        )!
        let timestamp = CMTime(seconds: 0.0, preferredTimescale: 600)

        XCTAssertThrowsError(try bridge.sendFrame(frame, timestamp: timestamp)) { error in
            XCTAssertEqual(error as? ExtensionBridgeError, .notConnected)
        }
    }

    func testSendFrameSucceedsWhenConnected() {
        bridge.connect()

        let frame = SyntheticFrameGenerator.solidColor(
            width: TestConstants.smallWidth,
            height: TestConstants.smallHeight,
            red: 100, green: 150, blue: 200
        )!
        let timestamp = CMTime(seconds: 0.0, preferredTimescale: 600)

        XCTAssertNoThrow(try bridge.sendFrame(frame, timestamp: timestamp))
    }

    // MARK: - Disconnect Clears Consumers

    func testDisconnectClearsActiveConsumers() {
        bridge.connect()
        bridge.handleResponse(.clientConnected(bundleIdentifier: "com.zoom.us"))
        bridge.handleResponse(.clientConnected(bundleIdentifier: "com.google.Chrome"))
        XCTAssertEqual(bridge.activeConsumers.count, 2)

        bridge.disconnect()

        XCTAssertTrue(bridge.activeConsumers.isEmpty)
        XCTAssertFalse(bridge.hasActiveConsumers)
    }
}
