@preconcurrency import AVFoundation
#if canImport(SwiftPMSupport)
import SwiftPMSupport
#endif

// MARK: -
/// The MediaRecorder class represents video and audio recorder.
public actor HKStreamRecorder {
    /// The MediaRecorder error domain codes.
    public enum Error: Swift.Error {
        /// An invalid internal stare.
        case invalidState
        /// Failed to create the AVAssetWriter.
        case failedToCreateAssetWriter(error: any Swift.Error)
        /// Failed to create the AVAssetWriterInput.
        case failedToCreateAssetWriterInput(error: any Swift.Error)
        /// Failed to append the PixelBuffer or SampleBuffer.
        case failedToAppend(error: (any Swift.Error)?)
        /// Failed to finish writing the AVAssetWriter.
        case failedToFinishWriting(error: (any Swift.Error)?)
    }

    /// Specifies the recorder settings.
    public var settings: [AVMediaType: [String: Any]] = [
        .audio: [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 0,
            AVNumberOfChannelsKey: 0
        ],
        .video: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoHeightKey: 0,
            AVVideoWidthKey: 0
        ]
    ]
    /// The recording file name.
    public private(set) var fileName: String?
    /// The running indicies whether recording or not.
    public private(set) var isRecording = false
    private var isReadyForStartWriting: Bool {
        guard let writer = writer else {
            return false
        }
        return settings.count == writer.inputs.count
    }
    private var continuation: AsyncStream<Error>.Continuation?
    private var writer: AVAssetWriter?
    private var writerInputs: [AVMediaType: AVAssetWriterInput] = [:]
    private var audioPresentationTime: CMTime = .zero
    private var videoPresentationTime: CMTime = .zero
    private var dimensions: CMVideoDimensions = .init(width: 0, height: 0)

    #if os(iOS)
    private lazy var moviesDirectory: URL = {
        URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
    }()
    #else
    private lazy var moviesDirectory: URL = {
        URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.moviesDirectory, .userDomainMask, true)[0])
    }()
    #endif

    /// Creates a new recorder.
    public init() {
    }

    /// Starts a recording.
    public func startRecording(_ filaName: String?, settings: [AVMediaType: [String: Any]]) async throws {
        guard !isRecording else {
            throw Error.invalidState
        }
        videoPresentationTime = .zero
        audioPresentationTime = .zero
        let fileName = fileName ?? UUID().uuidString
        let url = moviesDirectory.appendingPathComponent(fileName).appendingPathExtension("mp4")
        writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        isRecording = true
    }

    /// Stops a recording.
    public func stopRecording() async throws -> AVAssetWriter {
        guard isRecording else {
            throw Error.invalidState
        }
        guard let writer = writer, writer.status == .writing else {
            throw Error.failedToFinishWriting(error: writer?.error)
        }
        for (_, input) in writerInputs {
            input.markAsFinished()
        }
        await writer.finishWriting()
        defer {
            self.writer = nil
            self.writerInputs.removeAll()
        }
        return writer
    }

    private func append(_ sampleBuffer: CMSampleBuffer) {
        guard isRecording else {
            return
        }
        let mediaType: AVMediaType = (sampleBuffer.formatDescription?.mediaType == .video) ? .video : .audio
        guard
            let writer,
            let input = makeWriterInput(mediaType, sourceFormatHint: sampleBuffer.formatDescription),
            isReadyForStartWriting else {
            return
        }

        switch writer.status {
        case .unknown:
            writer.startWriting()
            writer.startSession(atSourceTime: sampleBuffer.presentationTimeStamp)
        default:
            break
        }

        if input.isReadyForMoreMediaData {
            switch mediaType {
            case .audio:
                if input.append(sampleBuffer) {
                    audioPresentationTime = sampleBuffer.presentationTimeStamp
                } else {
                    continuation?.yield(Error.failedToAppend(error: writer.error))
                }
            case .video:
                if input.append(sampleBuffer) {
                    videoPresentationTime = sampleBuffer.presentationTimeStamp
                } else {
                    continuation?.yield(Error.failedToAppend(error: writer.error))
                }
            default:
                break
            }
        }
    }

    private func makeWriterInput(_ mediaType: AVMediaType, sourceFormatHint: CMFormatDescription?) -> AVAssetWriterInput? {
        guard writerInputs[mediaType] == nil else {
            return writerInputs[mediaType]
        }

        var outputSettings: [String: Any] = [:]
        if let settings = self.settings[mediaType] {
            switch mediaType {
            case .audio:
                guard
                    let format = sourceFormatHint,
                    let inSourceFormat = format.audioStreamBasicDescription else {
                    break
                }
                for (key, value) in settings {
                    switch key {
                    case AVSampleRateKey:
                        outputSettings[key] = AnyUtil.isZero(value) ? inSourceFormat.mSampleRate : value
                    case AVNumberOfChannelsKey:
                        outputSettings[key] = AnyUtil.isZero(value) ? Int(inSourceFormat.mChannelsPerFrame) : value
                    default:
                        outputSettings[key] = value
                    }
                }
            case .video:
                dimensions = sourceFormatHint?.dimensions ?? .init(width: 0, height: 0)
                for (key, value) in settings {
                    switch key {
                    case AVVideoHeightKey:
                        outputSettings[key] = AnyUtil.isZero(value) ? Int(dimensions.height) : value
                    case AVVideoWidthKey:
                        outputSettings[key] = AnyUtil.isZero(value) ? Int(dimensions.width) : value
                    default:
                        outputSettings[key] = value
                    }
                }
            default:
                break
            }
        }

        var input: AVAssetWriterInput?
        if writer?.canApply(outputSettings: outputSettings, forMediaType: mediaType) == true {
            input = AVAssetWriterInput(mediaType: mediaType, outputSettings: outputSettings, sourceFormatHint: sourceFormatHint)
            input?.expectsMediaDataInRealTime = true
            self.writerInputs[mediaType] = input
            if let input {
                self.writer?.add(input)
            }
        }

        return input
    }
}

extension HKStreamRecorder: HKStreamOutput {
    // MARK: HKStreamOutput
    nonisolated public func stream(_ stream: some HKStream, didOutput video: CMSampleBuffer) {
        Task { await append(video) }
    }

    nonisolated public func stream(_ stream: some HKStream, didOutput audio: AVAudioBuffer, when: AVAudioTime) {
        guard let sampleBuffer = (audio as? AVAudioPCMBuffer)?.makeSampleBuffer(when) else {
            return
        }
        Task { await append(sampleBuffer) }
    }
}
