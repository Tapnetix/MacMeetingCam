import Foundation
import CoreMedia
import CoreVideo

/// Thread-safe ring buffer storing `(CVPixelBuffer, CMTime)` tuples
/// with timestamp-based eviction.
final class FrameBuffer {

    struct Entry {
        let buffer: CVPixelBuffer
        let timestamp: CMTime
    }

    // MARK: - Properties

    var maxDuration: TimeInterval {
        didSet { trim() }
    }

    private var entries: [Entry] = []
    private let lock = NSLock()

    // MARK: - Init

    init(maxDuration: TimeInterval) {
        self.maxDuration = maxDuration
    }

    // MARK: - Computed Properties

    var frameCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }

    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return entries.isEmpty
    }

    var oldestTimestamp: CMTime? {
        lock.lock()
        defer { lock.unlock() }
        return entries.first?.timestamp
    }

    var newestTimestamp: CMTime? {
        lock.lock()
        defer { lock.unlock() }
        return entries.last?.timestamp
    }

    /// Duration in seconds between oldest and newest timestamps.
    var currentDuration: TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        guard let oldest = entries.first?.timestamp,
              let newest = entries.last?.timestamp else {
            return 0
        }
        return CMTimeGetSeconds(newest) - CMTimeGetSeconds(oldest)
    }

    // MARK: - Methods

    func append(frame: CVPixelBuffer, timestamp: CMTime) {
        lock.lock()
        defer { lock.unlock() }
        entries.append(Entry(buffer: frame, timestamp: timestamp))
        trimLocked()
    }

    func allFrames() -> [Entry] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }

    func flush() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
    }

    // MARK: - Private

    private func trim() {
        lock.lock()
        defer { lock.unlock() }
        trimLocked()
    }

    /// Must be called while `lock` is held.
    private func trimLocked() {
        guard let newest = entries.last?.timestamp else { return }
        let newestSeconds = CMTimeGetSeconds(newest)
        let cutoff = newestSeconds - maxDuration
        entries.removeAll { CMTimeGetSeconds($0.timestamp) < cutoff }
    }
}
