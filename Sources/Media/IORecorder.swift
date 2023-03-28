import AVFoundation

/// The interface an IORecorder uses to inform its delegate.
public protocol IORecorderDelegate: AnyObject {
    /// Tells the receiver to recorder error occured.
    func recorder(_ recorder: IORecorder, errorOccured error: IORecorder.Error)
    /// Tells the receiver to finish writing.
    func recorder(_ recorder: IORecorder, finishWriting writer: AVAssetWriter)
}

// MARK: -
/// The IORecorder class represents video and audio recorder.
public class IORecorder {
    private static let interpolationThreshold = 1024 * 4

    /// The IORecorder error domain codes.
    public enum Error: Swift.Error {
        /// Failed to create the AVAssetWriter.
        case failedToCreateAssetWriter(error: Swift.Error)
        /// Failed to append the PixelBuffer or SampleBuffer.
        case failedToAppend(error: Swift.Error?)
        /// Failed to finish writing the AVAssetWriter.
        case failedToFinishWriting(error: Swift.Error?)
    }

    /// The default output settings for an IORecorder.
    public static let defaultOutputSettings: [AVMediaType: [String: Any]] = [
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

    /// Specifies the delegate.
    public weak var delegate: IORecorderDelegate?
    /// Specifies the recorder settings.
    public var outputSettings: [AVMediaType: [String: Any]] = IORecorder.defaultOutputSettings
    /// The running indicies whether recording or not.
    public private(set) var isRunning: Atomic<Bool> = .init(false)

    private let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.IORecorder.lock")
    private var isReadyForStartWriting: Bool {
        guard let writer = writer else {
            return false
        }
        return outputSettings.count == writer.inputs.count
    }
    private var writer: AVAssetWriter?
    private var writerInputs: [AVMediaType: AVAssetWriterInput] = [:]
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var audioPresentationTime = CMTime.zero
    private var videoPresentationTime = CMTime.zero

    #if os(iOS)
    private lazy var moviesDirectory: URL = {
        URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
    }()
    #else
    private lazy var moviesDirectory: URL = {
        URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.moviesDirectory, .userDomainMask, true)[0])
    }()
    #endif

    /// Append a sample buffer for recording.
    public func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer, mediaType: AVMediaType) {
        lockQueue.async {
            guard
                let writer = self.writer,
                let input = self.makeWriterInput(mediaType, sourceFormatHint: sampleBuffer.formatDescription),
                self.isReadyForStartWriting else {
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
                        self.audioPresentationTime = sampleBuffer.presentationTimeStamp
                    } else {
                        self.delegate?.recorder(self, errorOccured: .failedToAppend(error: writer.error))
                    }
                case .video:
                    if input.append(sampleBuffer) {
                        self.videoPresentationTime = sampleBuffer.presentationTimeStamp
                    } else {
                        self.delegate?.recorder(self, errorOccured: .failedToAppend(error: writer.error))
                    }
                default:
                    break
                }
            }
        }
    }

    /// Append a pixel buffer for recording.
    public func appendPixelBuffer(_ pixelBuffer: CVPixelBuffer, withPresentationTime: CMTime) {
        lockQueue.async {
            guard
                let writer = self.writer,
                let input = self.makeWriterInput(.video, sourceFormatHint: CMVideoFormatDescription.create(pixelBuffer: pixelBuffer)),
                let adaptor = self.makePixelBufferAdaptor(input),
                self.isReadyForStartWriting && self.videoPresentationTime.seconds < withPresentationTime.seconds else {
                return
            }

            switch writer.status {
            case .unknown:
                writer.startWriting()
                writer.startSession(atSourceTime: withPresentationTime)
            default:
                break
            }

            if input.isReadyForMoreMediaData {
                if adaptor.append(pixelBuffer, withPresentationTime: withPresentationTime) {
                    self.videoPresentationTime = withPresentationTime
                } else {
                    self.delegate?.recorder(self, errorOccured: .failedToAppend(error: writer.error))
                }
            }
        }
    }

    func finishWriting() {
        guard let writer = writer, writer.status == .writing else {
            delegate?.recorder(self, errorOccured: .failedToFinishWriting(error: writer?.error))
            return
        }
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        for (_, input) in writerInputs {
            input.markAsFinished()
        }
        writer.finishWriting {
            self.delegate?.recorder(self, finishWriting: writer)
            self.writer = nil
            self.writerInputs.removeAll()
            self.pixelBufferAdaptor = nil
            dispatchGroup.leave()
        }
        dispatchGroup.wait()
    }

    private func makeWriterInput(_ mediaType: AVMediaType, sourceFormatHint: CMFormatDescription?) -> AVAssetWriterInput? {
        guard writerInputs[mediaType] == nil else {
            return writerInputs[mediaType]
        }

        var outputSettings: [String: Any] = [:]
        if let defaultOutputSettings: [String: Any] = self.outputSettings[mediaType] {
            switch mediaType {
            case .audio:
                guard
                    let format = sourceFormatHint,
                    let inSourceFormat = format.streamBasicDescription?.pointee else {
                    break
                }
                for (key, value) in defaultOutputSettings {
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
                guard let format = sourceFormatHint else {
                    break
                }
                for (key, value) in defaultOutputSettings {
                    switch key {
                    case AVVideoHeightKey:
                        outputSettings[key] = AnyUtil.isZero(value) ? Int(format.dimensions.height) : value
                    case AVVideoWidthKey:
                        outputSettings[key] = AnyUtil.isZero(value) ? Int(format.dimensions.width) : value
                    default:
                        outputSettings[key] = value
                    }
                }
            default:
                break
            }
        }

        let input = AVAssetWriterInput(mediaType: mediaType, outputSettings: outputSettings, sourceFormatHint: sourceFormatHint)
        input.expectsMediaDataInRealTime = true
        writerInputs[mediaType] = input
        writer?.add(input)

        return input
    }

    private func makePixelBufferAdaptor(_ writerInput: AVAssetWriterInput?) -> AVAssetWriterInputPixelBufferAdaptor? {
        guard pixelBufferAdaptor == nil else {
            return pixelBufferAdaptor
        }
        guard let writerInput = writerInput else {
            return nil
        }
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: [:])
        pixelBufferAdaptor = adaptor
        return adaptor
    }
}

extension IORecorder: Running {
    // MARK: Running
    public func startRunning() {
        lockQueue.async {
            guard !self.isRunning.value else {
                return
            }
            do {
                self.videoPresentationTime = .zero
                self.audioPresentationTime = .zero
                let url = self.moviesDirectory.appendingPathComponent((UUID().uuidString)).appendingPathExtension("mp4")
                self.writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
                self.isRunning.mutate { $0 = true }
            } catch {
                self.delegate?.recorder(self, errorOccured: .failedToCreateAssetWriter(error: error))
            }
        }
    }

    public func stopRunning() {
        lockQueue.async {
            guard self.isRunning.value else {
                return
            }
            self.finishWriting()
            self.isRunning.mutate { $0 = false }
        }
    }
}
