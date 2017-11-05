import Foundation
import AVFoundation

public protocol AVMixerRecorderDelegate: class {
    var moviesDirectory:URL { get }
    func rotateFile(_ recorder:AVMixerRecorder, withPresentationTimeStamp:CMTime, mediaType:AVMediaType)
    func getPixelBufferAdaptor(_ recorder:AVMixerRecorder, withWriterInput: AVAssetWriterInput?) -> AVAssetWriterInputPixelBufferAdaptor?
    func getWriterInput(_ recorder:AVMixerRecorder, mediaType:AVMediaType, sourceFormatHint:CMFormatDescription?) -> AVAssetWriterInput?
    func didStartRunning(_ recorder: AVMixerRecorder)
    func didStopRunning(_ recorder: AVMixerRecorder)
    func didFinishWriting(_ recorder: AVMixerRecorder)
}

// MARK: -
open class AVMixerRecorder: NSObject {

    open static let defaultOutputSettings:[AVMediaType:[String:Any]] = [
        .audio: [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 0,
            AVNumberOfChannelsKey: 0,
        ],
        .video: [
            AVVideoCodecKey: AVVideoCodecH264,
            AVVideoHeightKey: 0,
            AVVideoWidthKey: 0,
        ],
    ]

    open var writer:AVAssetWriter?
    open var fileName:String?
    open var delegate:AVMixerRecorderDelegate?
    open var writerInputs:[AVMediaType:AVAssetWriterInput] = [:]
    open var outputSettings:[AVMediaType:[String:Any]] = AVMixerRecorder.defaultOutputSettings
    open var pixelBufferAdaptor:AVAssetWriterInputPixelBufferAdaptor?
    open let lockQueue:DispatchQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.AVMixerRecorder.lock")
    private(set) var running:Bool = false
    fileprivate(set) var sourceTime:CMTime = kCMTimeZero

    var isReadyForStartWriting:Bool {
        guard let writer:AVAssetWriter = writer else {
            return false
        }
        return outputSettings.count == writer.inputs.count
    }

    public override init() {
        super.init()
        delegate = DefaultAVMixerRecorderDelegate()
    }

    final func appendSampleBuffer(_ sampleBuffer:CMSampleBuffer, mediaType:AVMediaType) {
        lockQueue.async {
            guard let delegate:AVMixerRecorderDelegate = self.delegate, self.running else {
                return
            }

            delegate.rotateFile(self, withPresentationTimeStamp: sampleBuffer.presentationTimeStamp, mediaType: mediaType)

            guard
                let writer:AVAssetWriter = self.writer,
                let input:AVAssetWriterInput = delegate.getWriterInput(self, mediaType: mediaType, sourceFormatHint: sampleBuffer.formatDescription),
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

            if (input.isReadyForMoreMediaData) {
                input.append(sampleBuffer)
            }
        }
    }

    final func appendPixelBuffer(_ pixelBuffer:CVPixelBuffer,  withPresentationTime:CMTime) {
        lockQueue.async {
            guard let delegate:AVMixerRecorderDelegate = self.delegate, self.running else {
                return
            }

            delegate.rotateFile(self, withPresentationTimeStamp: withPresentationTime, mediaType: .video)
            guard
                let writer:AVAssetWriter = self.writer,
                let input:AVAssetWriterInput = delegate.getWriterInput(self, mediaType: .video, sourceFormatHint: CMVideoFormatDescription.create(withPixelBuffer: pixelBuffer)),
                let adaptor:AVAssetWriterInputPixelBufferAdaptor = delegate.getPixelBufferAdaptor(self, withWriterInput: input),
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

            if (input.isReadyForMoreMediaData) {
                adaptor.append(pixelBuffer, withPresentationTime: withPresentationTime)
            }
        }
    }

    func finishWriting() {
        guard let writer:AVAssetWriter = writer, writer.status == .writing else {
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

extension AVMixerRecorder: Runnable {
    // MARK: Runnable
    final func startRunning() {
        lockQueue.async {
            guard !self.running else {
                return
            }
            self.running = true
            self.delegate?.didStartRunning(self)
        }
    }

    final func stopRunning() {
        lockQueue.async {
            guard self.running else {
                return
            }
            self.finishWriting()
            self.running = false
            self.delegate?.didStopRunning(self)
        }
    }
}

// MARK: -
open class DefaultAVMixerRecorderDelegate: NSObject {
    open var duration:Int64 = 0
    open var dateFormat:String = "-yyyyMMdd-HHmmss"

    private var rotateTime:CMTime = kCMTimeZero
    private var clockReference:AVMediaType = .video

    #if os(iOS)
    open lazy var moviesDirectory:URL = {
        return URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
    }()
    #else
    open lazy var moviesDirectory:URL = {
        return URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.moviesDirectory, .userDomainMask, true)[0])
    }()
    #endif
}

@objc
extension DefaultAVMixerRecorderDelegate: AVMixerRecorderDelegate {
    // MARK: AVMixerRecorderDelegate
    open func rotateFile(_ recorder:AVMixerRecorder, withPresentationTimeStamp:CMTime, mediaType:AVMediaType) {
        guard clockReference == mediaType && rotateTime.value < withPresentationTimeStamp.value else {
            return
        }
        if let _:AVAssetWriter = recorder.writer {
            recorder.finishWriting()
        }
        recorder.writer = createWriter(recorder.fileName)
        rotateTime = CMTimeAdd(
            withPresentationTimeStamp,
            CMTimeMake(duration == 0 ? Int64.max : duration * Int64(withPresentationTimeStamp.timescale), withPresentationTimeStamp.timescale)
        )
        recorder.sourceTime = withPresentationTimeStamp
    }

    open func getPixelBufferAdaptor(_ recorder: AVMixerRecorder, withWriterInput: AVAssetWriterInput?) -> AVAssetWriterInputPixelBufferAdaptor? {
        guard recorder.pixelBufferAdaptor == nil else {
            return recorder.pixelBufferAdaptor
        }
        guard let writerInput:AVAssetWriterInput = withWriterInput else {
            return nil
        }
        let adaptor:AVAssetWriterInputPixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: [:])
        recorder.pixelBufferAdaptor = adaptor
        return adaptor
    }

    open func getWriterInput(_ recorder:AVMixerRecorder, mediaType:AVMediaType, sourceFormatHint:CMFormatDescription?) -> AVAssetWriterInput? {
        guard recorder.writerInputs[mediaType] == nil else {
            return recorder.writerInputs[mediaType]
        }

        var outputSettings:[String:Any] = [:]
        if let defaultOutputSettings:[String:Any] = recorder.outputSettings[mediaType] {
            switch mediaType {
            case .audio:
                guard
                    let format:CMAudioFormatDescription = sourceFormatHint,
                    let inSourceFormat:AudioStreamBasicDescription = format.streamBasicDescription?.pointee else {
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
                guard let format:CMVideoFormatDescription = sourceFormatHint else {
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

        let input:AVAssetWriterInput = AVAssetWriterInput(mediaType: mediaType, outputSettings: outputSettings, sourceFormatHint: sourceFormatHint)
        input.expectsMediaDataInRealTime = true
        recorder.writerInputs[mediaType] = input
        recorder.writer?.add(input)

        return input
    }

    open func didFinishWriting(_ recorder:AVMixerRecorder) {
    }

    open func didStartRunning(_ recorder: AVMixerRecorder) {
    }

    open func didStopRunning(_ recorder: AVMixerRecorder) {
        rotateTime = kCMTimeZero
    }

    func createWriter(_ fileName: String?) -> AVAssetWriter? {
        do {
            let dateFormatter:DateFormatter = DateFormatter()
            dateFormatter.locale = NSLocale(localeIdentifier: "en_US") as Locale!
            dateFormatter.dateFormat = dateFormat
            var fileComponent:String? = nil
            if var fileName:String = fileName {
                if let q:String.CharacterView.Index = fileName.characters.index(of: "?") {
                    fileName.removeSubrange(q..<fileName.characters.endIndex)
                }
                fileComponent = fileName + dateFormatter.string(from: Date())
            }
            let url:URL = moviesDirectory.appendingPathComponent((fileComponent ?? UUID().uuidString) + ".mp4")
            logger.info("\(url)")
            return try AVAssetWriter(outputURL: url, fileType: AVFileType.mp4)
        } catch {
            logger.warn("create an AVAssetWriter")
        }
        return nil
    }
}
