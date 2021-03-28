import AVFoundation

public protocol AVRecorderDelegate: AnyObject {
    var moviesDirectory: URL { get }

    func rotateFile(_ recorder: AVRecorder, withPresentationTimeStamp: CMTime, mediaType: AVMediaType)
    func getPixelBufferAdaptor(_ recorder: AVRecorder, withWriterInput: AVAssetWriterInput?) -> AVAssetWriterInputPixelBufferAdaptor?
    func getWriterInput(_ recorder: AVRecorder, mediaType: AVMediaType, sourceFormatHint: CMFormatDescription?) -> AVAssetWriterInput?
    func didStartRunning(_ recorder: AVRecorder)
    func didStopRunning(_ recorder: AVRecorder)
    func didFinishWriting(_ recorder: AVRecorder)
}

// MARK: -
open class AVRecorder: NSObject {
    public static let defaultOutputSettings: [AVMediaType: [String: Any]] = [
        .audio: [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 0,
            AVNumberOfChannelsKey: 0
        ],
        .video: [
            AVVideoCodecKey: AVVideoCodecH264,
            AVVideoHeightKey: 0,
            AVVideoWidthKey: 0
        ]
    ]

    open var writer: AVAssetWriter?
    open var fileName: String?
    open weak var delegate: AVRecorderDelegate? = DefaultAVRecorderDelegate.shared
    open var writerInputs: [AVMediaType: AVAssetWriterInput] = [:]
    open var outputSettings: [AVMediaType: [String: Any]] = AVRecorder.defaultOutputSettings
    open var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    public let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.AVRecorder.lock")
    public private(set) var isRunning: Atomic<Bool> = .init(false)
    fileprivate(set) var sourceTime = CMTime.zero

    var isReadyForStartWriting: Bool {
        guard let writer: AVAssetWriter = writer else {
            return false
        }
        return outputSettings.count == writer.inputs.count
    }

    final func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer, mediaType: AVMediaType) {
        lockQueue.async {
            guard let delegate: AVRecorderDelegate = self.delegate, self.isRunning.value else {
                return
            }

            delegate.rotateFile(self, withPresentationTimeStamp: sampleBuffer.presentationTimeStamp, mediaType: mediaType)

            guard
                let writer: AVAssetWriter = self.writer,
                let input: AVAssetWriterInput = delegate.getWriterInput(self, mediaType: mediaType, sourceFormatHint: sampleBuffer.formatDescription),
                self.isReadyForStartWriting else {
                return
            }

            switch writer.status {
            case .unknown:
                writer.startWriting()
                writer.startSession(atSourceTime: self.sourceTime)
            default:
                break
            }

            if input.isReadyForMoreMediaData {
                input.append(sampleBuffer)
            }
        }
    }

    final func appendPixelBuffer(_ pixelBuffer: CVPixelBuffer, withPresentationTime: CMTime) {
        lockQueue.async {
            guard let delegate: AVRecorderDelegate = self.delegate, self.isRunning.value else {
                return
            }

            delegate.rotateFile(self, withPresentationTimeStamp: withPresentationTime, mediaType: .video)
            guard
                let writer = self.writer,
                let input = delegate.getWriterInput(self, mediaType: .video, sourceFormatHint: CMVideoFormatDescription.create(pixelBuffer: pixelBuffer)),
                let adaptor = delegate.getPixelBufferAdaptor(self, withWriterInput: input),
                self.isReadyForStartWriting else {
                return
            }

            switch writer.status {
            case .unknown:
                writer.startWriting()
                writer.startSession(atSourceTime: self.sourceTime)
            default:
                break
            }

            if input.isReadyForMoreMediaData {
                adaptor.append(pixelBuffer, withPresentationTime: withPresentationTime)
            }
        }
    }

    func finishWriting() {
        guard let writer: AVAssetWriter = writer, writer.status == .writing else {
            return
        }
        for (_, input) in writerInputs {
            input.markAsFinished()
        }
        writer.finishWriting {
            self.delegate?.didFinishWriting(self)
            self.writer = nil
            self.writerInputs.removeAll()
            self.pixelBufferAdaptor = nil
        }
    }
}

extension AVRecorder: Running {
    // MARK: Running
    public func startRunning() {
        lockQueue.async {
            guard !self.isRunning.value else {
                return
            }
            self.isRunning.mutate { $0 = true }
            self.delegate?.didStartRunning(self)
        }
    }

    public func stopRunning() {
        lockQueue.async {
            guard self.isRunning.value else {
                return
            }
            self.finishWriting()
            self.isRunning.mutate { $0 = false }
            self.delegate?.didStopRunning(self)
        }
    }
}

// MARK: -
open class DefaultAVRecorderDelegate: NSObject {
    public enum FileType {
        case mp4
        case mov

        public var AVFileType: AVFileType {
            switch self {
            case .mp4:
                return .mp4
            case .mov:
                return .mov
            }
        }

        public var fileExtension: String {
            switch self {
            case .mp4:
                return ".mp4"
            case .mov:
                return ".mov"
            }
        }
    }

    public static let shared = DefaultAVRecorderDelegate()

    open var duration: Int64 = 0
    open var dateFormat: String = "-yyyyMMdd-HHmmss"

    private var rotateTime = CMTime.zero
    private var clockReference: AVMediaType = .video
    public private(set) var fileType: FileType

    #if os(iOS)
    open lazy var moviesDirectory: URL = {
        URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
    }()
    #else
    open lazy var moviesDirectory: URL = {
        URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.moviesDirectory, .userDomainMask, true)[0])
    }()
    #endif

    public init(fileType: FileType = .mp4)
    {
        self.fileType = fileType
    }
}

@objc
extension DefaultAVRecorderDelegate: AVRecorderDelegate {
    // MARK: AVRecorderDelegate
    open func rotateFile(_ recorder: AVRecorder, withPresentationTimeStamp: CMTime, mediaType: AVMediaType) {
        guard clockReference == mediaType && rotateTime.value < withPresentationTimeStamp.value else {
            return
        }
        if recorder.writer != nil {
            recorder.finishWriting()
        }
        recorder.writer = createWriter(recorder.fileName)
        rotateTime = CMTimeAdd(
            withPresentationTimeStamp,
            CMTimeMake(value: duration == 0 ? .max : duration * Int64(withPresentationTimeStamp.timescale), timescale: withPresentationTimeStamp.timescale)
        )
        recorder.sourceTime = withPresentationTimeStamp
    }

    open func getPixelBufferAdaptor(_ recorder: AVRecorder, withWriterInput: AVAssetWriterInput?) -> AVAssetWriterInputPixelBufferAdaptor? {
        guard recorder.pixelBufferAdaptor == nil else {
            return recorder.pixelBufferAdaptor
        }
        guard let writerInput: AVAssetWriterInput = withWriterInput else {
            return nil
        }
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: [:])
        recorder.pixelBufferAdaptor = adaptor
        return adaptor
    }

    open func getWriterInput(_ recorder: AVRecorder, mediaType: AVMediaType, sourceFormatHint: CMFormatDescription?) -> AVAssetWriterInput? {
        guard recorder.writerInputs[mediaType] == nil else {
            return recorder.writerInputs[mediaType]
        }

        var outputSettings: [String: Any] = [:]
        if let defaultOutputSettings: [String: Any] = recorder.outputSettings[mediaType] {
            switch mediaType {
            case .audio:
                guard
                    let format: CMAudioFormatDescription = sourceFormatHint,
                    let inSourceFormat: AudioStreamBasicDescription = format.streamBasicDescription?.pointee else {
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
                guard let format: CMVideoFormatDescription = sourceFormatHint else {
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
        recorder.writerInputs[mediaType] = input
        recorder.writer?.add(input)

        return input
    }

    open func didFinishWriting(_ recorder: AVRecorder) {
    }

    open func didStartRunning(_ recorder: AVRecorder) {
    }

    open func didStopRunning(_ recorder: AVRecorder) {
        rotateTime = CMTime.zero
    }

    func createWriter(_ fileName: String?) -> AVAssetWriter? {
        do {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US")
            dateFormatter.dateFormat = dateFormat
            var fileComponent: String?
            if var fileName: String = fileName {
                if let q: String.Index = fileName.firstIndex(of: "?") {
                    fileName.removeSubrange(q..<fileName.endIndex)
                }
                fileComponent = fileName + dateFormatter.string(from: Date())
            }
            let url: URL = moviesDirectory.appendingPathComponent((fileComponent ?? UUID().uuidString) + fileType.fileExtension)
            logger.info("\(url)")
            return try AVAssetWriter(outputURL: url, fileType: fileType.AVFileType)
        } catch {
            logger.warn("create an AVAssetWriter")
        }
        return nil
    }
}
