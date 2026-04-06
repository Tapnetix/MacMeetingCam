import Foundation

enum MemoryEstimator {

    /// Estimates raw memory usage in bytes for a loop buffer.
    ///
    /// Formula: `frames * width * height * bytesPerPixel`
    /// where `frames = durationSeconds * fps` and `bytesPerPixel = 4` (BGRA).
    static func estimateBytes(
        durationSeconds: TimeInterval,
        width: Int,
        height: Int,
        fps: Int
    ) -> Int {
        let frames = Int(durationSeconds) * fps
        return frames * width * height * AppConstants.Defaults.bytesPerPixel
    }

    /// Returns a human-readable memory estimate such as "~1.2 GB" or "~450 MB".
    static func formattedEstimate(
        durationSeconds: TimeInterval,
        width: Int,
        height: Int,
        fps: Int
    ) -> String {
        let bytes = estimateBytes(
            durationSeconds: durationSeconds,
            width: width,
            height: height,
            fps: fps
        )
        let megabytes = Double(bytes) / 1_000_000
        if megabytes >= 1_000 {
            let gigabytes = megabytes / 1_000
            return String(format: "~%.1f GB", gigabytes)
        } else {
            return String(format: "~%.0f MB", megabytes)
        }
    }
}
