import CoreMedia
import Foundation

public final actor MediaLink {
    public var dequeue: AsyncStream<CMSampleBuffer> {
        let (stream, continutation) = AsyncStream<CMSampleBuffer>.makeStream()
        self.continutation = continutation
        return stream
    }
    public private(set) var isRunning = false
    private var storage: TypedBlockQueue<CMSampleBuffer>?
    private var continutation: AsyncStream<CMSampleBuffer>.Continuation? {
        didSet {
            oldValue?.finish()
        }
    }
    private var presentationTimeStampOrigin: CMTime = .invalid
    private weak var audioPlayer: AudioPlayerNode?

    /// Creates a new instance.
    public init() {
        do {
            storage = try .init(capacity: 90, handlers: .outputPTSSortedSampleBuffers)
        } catch {
            logger.error(error)
        }
    }

    public func enqueue(_ sampleBuffer: CMSampleBuffer) {
        guard isRunning else {
            return
        }
        if presentationTimeStampOrigin == .invalid {
            presentationTimeStampOrigin = sampleBuffer.presentationTimeStamp
        }
        do {
            try storage?.enqueue(sampleBuffer)
        } catch {
            logger.error(error)
        }
    }

    public func setAudioPlayer(_ audioPlayer: AudioPlayerNode?) {
        self.audioPlayer = audioPlayer
    }
}

extension MediaLink: AsyncRunner {
    // MARK: AsyncRunner
    public func startRunning() {
        guard !isRunning else {
            return
        }
        isRunning = true
        Task {
            for await currentTime in AsyncDisplayLink.updateFrames where isRunning {
                guard let storage else {
                    continue
                }
                let currentTime = await audioPlayer?.currentTime ?? currentTime
                var frameCount = 0
                while !storage.isEmpty {
                    guard let first = storage.head else {
                        break
                    }
                    if first.presentationTimeStamp.seconds - presentationTimeStampOrigin.seconds <= currentTime {
                        continutation?.yield(first)
                        frameCount += 1
                        _ = storage.dequeue()
                    } else {
                        if 2 < frameCount {
                            logger.info("droppedFrame: \(frameCount)")
                        }
                        break
                    }
                }
            }
        }
    }

    public func stopRunning() {
        guard isRunning else {
            return
        }
        continutation = nil
        presentationTimeStampOrigin = .invalid
        try? storage?.reset()
        isRunning = false
    }
}
