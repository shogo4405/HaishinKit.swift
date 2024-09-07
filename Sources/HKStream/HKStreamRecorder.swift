@preconcurrency import AVFoundation

// MARK: -
/// An actor represents video and audio recorder.
///
/// This actor is compatible with both HKStreamOutput and MediaMixerOutput. This means it can record the output from MediaMixer in addition to HKStream.
///
/// ```
///  // An example of recording MediaMixer.
///  let recorder = HKStreamRecorder()
///  let mixer = MediaMixer()
///  mixer.addOutput(recorder)
/// ```
/// ```
///  // An example of recording streaming.
///  let recorder = HKStreamRecorder()
///  let mixer = MediaMixer()
///  let stream = RTMPStream()
///  mixer.addOutput(stream)
///  stream.addOutput(recorder)
/// ```
public actor HKStreamRecorder {
    /// The error domain codes.
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

    /// The default recording settings.
    public static let defaultSettings: [AVMediaType: [String: any Sendable]] = [
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

    private static func isZero(_ value: any Sendable) -> Bool {
        switch value {
        case let value as Int:
            return value == 0
        case let value as Double:
            return value == 0
        default:
            return false
        }
    }

    /// The recorder settings.
    public private(set) var settings: [AVMediaType: [String: any Sendable]] = HKStreamRecorder.defaultSettings
    /// The recording file name.
    public private(set) var fileName: String?
    /// The recording or not.
    public private(set) var isRecording = false
    private var isReadyForStartWriting: Bool {
        guard let writer = writer else {
            return false
        }
        return settings.count == writer.inputs.count
    }
    private var writer: AVAssetWriter?
    private var trackId: UInt8 = 0
    private var continuation: AsyncStream<Error>.Continuation?
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

    /// Sets the video track id for recording.
    public func setTrackId(_ trackId: UInt8) throws {
        guard isRecording else {
            throw Error.invalidState
        }
        self.trackId = trackId
    }

    /// Starts recording.
    public func startRecording(_ filaName: String? = nil, settings: [AVMediaType: [String: any Sendable]] = HKStreamRecorder.defaultSettings) async throws {
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

    /// Stops recording.
    ///
    /// ## Example of saving to the Photos app.
    /// ```
    ///  do {
    ///    let outputURL = try await recorder.stopRecording()
    ///    PHPhotoLibrary.shared().performChanges({() -> Void in
    ///      PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
    ///    }, completionHandler: { _, error -> Void in
    ///      try? FileManager.default.removeItem(at: outputURL)
    ///    }
    ///  } catch {
    ///     print(error)
    ///  }
    /// ```
    public func stopRecording() async throws -> URL {
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
            isRecording = false
            self.writer = nil
            self.writerInputs.removeAll()
        }
        return writer.outputURL
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
                        outputSettings[key] = Self.isZero(value) ? inSourceFormat.mSampleRate : value
                    case AVNumberOfChannelsKey:
                        outputSettings[key] = Self.isZero(value) ? Int(inSourceFormat.mChannelsPerFrame) : value
                    default:
                        outputSettings[key] = value
                    }
                }
            case .video:
                dimensions = sourceFormatHint?.dimensions ?? .init(width: 0, height: 0)
                for (key, value) in settings {
                    switch key {
                    case AVVideoHeightKey:
                        outputSettings[key] = Self.isZero(value) ? Int(dimensions.height) : value
                    case AVVideoWidthKey:
                        outputSettings[key] = Self.isZero(value) ? Int(dimensions.width) : value
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

extension HKStreamRecorder: MediaMixerOutput {
    // MARK: MediaMixerOutput
    nonisolated public func mixer(_ mixer: MediaMixer, track: UInt8, didOutput sampleBuffer: CMSampleBuffer) {
        Task {
            guard await trackId == track else {
                return
            }
            await append(sampleBuffer)
        }
    }

    nonisolated public func mixer(_ mixer: MediaMixer, track: UInt8, didOutput buffer: AVAudioPCMBuffer, when: AVAudioTime) {
        guard let sampleBuffer = buffer.makeSampleBuffer(when) else {
            return
        }
        Task {
            await append(sampleBuffer)
        }
    }
}
