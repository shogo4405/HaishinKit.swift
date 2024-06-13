import AVFoundation
import CoreFoundation
import VideoToolbox
#if canImport(UIKit)
import UIKit
#endif

// MARK: -
/**
 * The VideoCodec class provides methods for encode or decode for video.
 */
final class VideoCodec {
    static let frameInterval: Double = 0.0

    /// Specifies the settings for a VideoCodec.
    var settings: VideoCodecSettings = .default {
        didSet {
            let invalidateSession = settings.invalidateSession(oldValue)
            if invalidateSession {
                self.invalidateSession = invalidateSession
            } else {
                settings.apply(self, rhs: oldValue)
            }
        }
    }
    var needsSync = true
    var passthrough = true
    var frameInterval = VideoCodec.frameInterval
    var expectedFrameRate = IOMixer.defaultFrameRate
    /// The running value indicating whether the VideoCodec is running.
    private(set) var isRunning = false
    private(set) var inputFormat: CMFormatDescription? {
        didSet {
            guard inputFormat != oldValue else {
                return
            }
            invalidateSession = true
            outputFormat = nil
        }
    }
    private(set) var session: (any VTSessionConvertible)? {
        didSet {
            oldValue?.invalidate()
            invalidateSession = false
        }
    }
    private(set) var outputFormat: CMFormatDescription?
    private(set) lazy var outputStream: AsyncStream<CMSampleBuffer> = {
        let (stream, continuation) = AsyncStream.makeStream(of: CMSampleBuffer.self)
        self.outputContinuation = continuation
        return stream
    }()
    private var startedAt: CMTime = .zero
    private var invalidateSession = true
    private var inputContinuation: AsyncStream<CMSampleBuffer>.Continuation?
    private var outputContinuation: AsyncStream<CMSampleBuffer>.Continuation?
    private var presentationTimeStamp: CMTime = .invalid

    func append(_ sampleBuffer: CMSampleBuffer) {
        inputContinuation?.yield(sampleBuffer)
    }

    func imageBufferAttributes(_ mode: VTSessionMode) -> [NSString: AnyObject]? {
        switch mode {
        case .compression:
            var attributes: [NSString: AnyObject] = [:]
            if let inputFormat {
                // Specify the pixel format of the uncompressed video.
                attributes[kCVPixelBufferPixelFormatTypeKey] = inputFormat.mediaType.rawValue as CFNumber
            }
            return attributes.isEmpty ? nil : attributes
        case .decompression:
            return [
                kCVPixelBufferIOSurfacePropertiesKey: NSDictionary(),
                kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue
            ]
        }
    }

    private func convert(_ sampleBuffer: CMSampleBuffer) async throws {
        inputFormat = sampleBuffer.formatDescription
        if invalidateSession {
            if sampleBuffer.formatDescription?.isCompressed == true {
                session = try VTSessionMode.decompression.makeSession(self)
            } else {
                session = try VTSessionMode.compression.makeSession(self)
            }
        }
        guard let session else {
            throw VTSessionError.failedToCreate(status: kVTParameterErr)
        }
        let sampleBuffer = try await session.convert(sampleBuffer)
        outputContinuation?.yield(sampleBuffer)
    }

    private func willDropFrame(_ presentationTimeStamp: CMTime) -> Bool {
        guard startedAt <= presentationTimeStamp else {
            return true
        }
        guard Self.frameInterval < frameInterval else {
            return false
        }
        return presentationTimeStamp.seconds - self.presentationTimeStamp.seconds <= frameInterval
    }

    #if os(iOS) || os(tvOS) || os(visionOS)
    @objc
    private func applicationWillEnterForeground(_ notification: Notification) {
        invalidateSession = true
    }

    @objc
    private func didAudioSessionInterruption(_ notification: Notification) {
        guard
            let userInfo: [AnyHashable: Any] = notification.userInfo,
            let value: NSNumber = userInfo[AVAudioSessionInterruptionTypeKey] as? NSNumber,
            let type = AVAudioSession.InterruptionType(rawValue: value.uintValue) else {
            return
        }
        switch type {
        case .ended:
            invalidateSession = true
        default:
            break
        }
    }
    #endif
}

extension VideoCodec: Runner {
    // MARK: Running
    func startRunning() {
        guard !isRunning else {
            return
        }
        #if os(iOS) || os(tvOS) || os(visionOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.didAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.applicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        #endif
        let (stream, continuation) = AsyncStream.makeStream(of: CMSampleBuffer.self)
        inputContinuation = continuation
        Task {
            for await sampleBuffer in stream where isRunning {
                try? await convert(sampleBuffer)
            }
        }
        startedAt = passthrough ? .zero : CMClockGetTime(CMClockGetHostTimeClock())
        isRunning = true
    }

    func stopRunning() {
        guard isRunning else {
            return
        }
        inputContinuation?.finish()
        isRunning = false
        session = nil
        invalidateSession = true
        needsSync = true
        inputFormat = nil
        outputFormat = nil
        // presentationTimeStamp = .invalid
        startedAt = .zero
        #if os(iOS) || os(tvOS) || os(visionOS)
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
        #endif
    }
}
