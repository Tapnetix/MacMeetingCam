import CoreMedia

enum TestConstants {
    static let defaultWidth = 1920
    static let defaultHeight = 1080
    static let smallWidth = 640
    static let smallHeight = 480
    static let defaultFPS = 30
    static let frameDuration = CMTime(value: 1, timescale: 30)
    static let floatTolerance: Double = 0.001
    static let asyncTimeout: TimeInterval = 5.0
}
