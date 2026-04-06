import Foundation

enum AppConstants {
    static let appName = "MacMeetingCam"
    static let virtualCameraName = "MacMeetingCam"
    static let bundleIdentifier = "com.tapnetix.MacMeetingCam"
    static let extensionBundleIdentifier = "com.tapnetix.MacMeetingCam.CameraExtension"

    enum Defaults {
        static let bufferDuration: TimeInterval = 30.0
        static let minBufferDuration: TimeInterval = 3.0
        static let maxBufferDuration: TimeInterval = 120.0
        static let crossfadeDuration: TimeInterval = 0.5
        static let minCrossfadeDuration: TimeInterval = 0.3
        static let maxCrossfadeDuration: TimeInterval = 1.5
        static let resumeTransition: TimeInterval = 0.3
        static let minResumeTransition: TimeInterval = 0.1
        static let maxResumeTransition: TimeInterval = 1.0
        static let blurIntensity: Double = 0.75
        static let edgeSoftness: Double = 0.30
        static let targetFramerate: Int = 30
        static let bytesPerPixel: Int = 4  // BGRA
    }
}
