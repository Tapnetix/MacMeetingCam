import Foundation

struct MockCameraDescriptor: Equatable, Identifiable {
    let id: String
    let name: String
    let modelID: String
    let width: Int
    let height: Int
    let frameRates: [Int]

    static let builtInWide = MockCameraDescriptor(
        id: "built-in-wide", name: "FaceTime HD Camera", modelID: "FaceTimeHD",
        width: 1920, height: 1080, frameRates: [24, 30]
    )
    static let externalUSB = MockCameraDescriptor(
        id: "usb-cam-001", name: "USB Webcam", modelID: "GenericUSB",
        width: 1280, height: 720, frameRates: [30, 60]
    )
    static let allMocks: [MockCameraDescriptor] = [builtInWide, externalUSB]
}
