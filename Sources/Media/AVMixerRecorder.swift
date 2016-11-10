import Foundation
import AVFoundation
#if os(iOS)
import Photos
#endif

public protocol AVMixerRecorderDelegate: class {
    var moviesDirectory:URL { get }
    func rotateFile(_ recorder:AVMixerRecorder, sampleBuffer:CMSampleBuffer, mediaType:String)
    func getWriterInput(_ recorder:AVMixerRecorder, mediaType:String, sourceFormatHint:CMFormatDescription?) -> AVAssetWriterInput?
    func didStartRunning(_ recorder: AVMixerRecorder)
    func didStopRunning(_ recorder: AVMixerRecorder)
    func didFinishWriting(_ recorder: AVMixerRecorder)
}

// MARK: -
open class AVMixerRecorder: NSObject {

    open static let defaultOutputSettings:[String:[String:Any]] = [
        AVMediaTypeAudio: [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 0,
            AVNumberOfChannelsKey: 0,
        ],
        AVMediaTypeVideo: [
            AVVideoCodecKey: AVVideoCodecH264,
            AVVideoHeightKey: 0,
            AVVideoWidthKey: 0,
        ],
    ]

    open var writer:AVAssetWriter?
    open var fileName:String?
    open var writerInputs:[String:AVAssetWriterInput] = [:]
    open var outputSettings:[String:[String:Any]] = AVMixerRecorder.defaultOutputSettings
    open var delegate:AVMixerRecorderDelegate?
    open let lockQueue:DispatchQueue = DispatchQueue(label: "com.github.shogo4405.lf.AVMixerRecorder.lock")
    fileprivate(set) var running:Bool = false

    public override init() {
        super.init()
        delegate = DefaultAVMixerRecorderDelegate()
    }

    final func appendSampleBuffer(_ sampleBuffer:CMSampleBuffer, mediaType:String) {
        lockQueue.async {
            guard let delegate:AVMixerRecorderDelegate = self.delegate , self.running else {
                return
            }

            delegate.rotateFile(self, sampleBuffer: sampleBuffer, mediaType: mediaType)

            guard let
                writer:AVAssetWriter = self.writer,
                let input:AVAssetWriterInput = delegate.getWriterInput(self, mediaType: mediaType, sourceFormatHint: sampleBuffer.formatDescription) else {
                return
            }

            switch writer.status {
            case .unknown:
                writer.startWriting()
                writer.startSession(atSourceTime: sampleBuffer.presentationTimeStamp)
            default:
                break
            }
            if (input.isReadyForMoreMediaData) {
                input.append(sampleBuffer)
            }
        }
    }

    func finishWriting() {
        for (_, input) in writerInputs {
            input.markAsFinished()
        }
        writer?.finishWriting {
            self.delegate?.didFinishWriting(self)
            self.writer = nil
            self.writerInputs.removeAll()
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
    fileprivate var rotateTime:CMTime = kCMTimeZero
    fileprivate var clockReference:String = AVMediaTypeVideo

    #if os(OSX)
    public lazy var moviesDirectory:URL = {
        return URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.moviesDirectory, .userDomainMask, true)[0])
    }()
    #else
    open lazy var moviesDirectory:URL = {
        return URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
    }()
    #endif
}

extension DefaultAVMixerRecorderDelegate: AVMixerRecorderDelegate {
    // MARK: AVMixerRecorderDelegate
    public func rotateFile(_ recorder:AVMixerRecorder, sampleBuffer:CMSampleBuffer, mediaType:String) {
        let presentationTimeStamp:CMTime = sampleBuffer.presentationTimeStamp
        guard clockReference == mediaType && rotateTime.value < presentationTimeStamp.value else {
            return
        }
        if let _:AVAssetWriter = recorder.writer {
            recorder.finishWriting()
        }
        recorder.writer = createWriter(recorder.fileName)
        rotateTime = CMTimeAdd(
            presentationTimeStamp,
            CMTimeMake(duration == 0 ? Int64.max : duration * Int64(presentationTimeStamp.timescale), presentationTimeStamp.timescale)
        )
    }

    public func getWriterInput(_ recorder:AVMixerRecorder, mediaType:String, sourceFormatHint:CMFormatDescription?) -> AVAssetWriterInput? {
        guard recorder.writerInputs[mediaType] == nil else {
            return recorder.writerInputs[mediaType]
        }
        var outputSettings:[String:Any] = [:]
        if let defaultOutputSettings:[String:Any] = recorder.outputSettings[mediaType] {
            if (mediaType == AVMediaTypeAudio) {
                let inSourceFormat:AudioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(sourceFormatHint!)!.pointee
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
            }
            if (mediaType == AVMediaTypeVideo) {
                let dimensions:CMVideoDimensions = CMVideoFormatDescriptionGetDimensions(sourceFormatHint!)
                for (key, value) in defaultOutputSettings {
                    switch key {
                    case AVVideoHeightKey:
                        outputSettings[key] = AnyUtil.isZero(value) ? Int(dimensions.height) : value
                    case AVVideoWidthKey:
                        outputSettings[key] = AnyUtil.isZero(value) ? Int(dimensions.width) : value
                    default:
                        outputSettings[key] = value
                    }
                }
            }
        }
        var input:AVAssetWriterInput?
        input = AVAssetWriterInput(mediaType: mediaType, outputSettings: outputSettings, sourceFormatHint: sourceFormatHint)
        recorder.writerInputs[mediaType] = input
        recorder.writer?.add(input!)
        return input
    }

    public func didFinishWriting(_ recorder:AVMixerRecorder) {
    #if os(iOS)
        guard let writer:AVAssetWriter = recorder.writer else {
            return
        }
        PHPhotoLibrary.shared().performChanges({() -> Void in
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: writer.outputURL)
        }, completionHandler: { (isSuccess, error) -> Void in
            do {
                try FileManager.default.removeItem(at: writer.outputURL)
            } catch let error as NSError {
                logger.error("\(error)")
            }
        })
    #endif
    }

    public func didStartRunning(_ recorder: AVMixerRecorder) {
    }

    public func didStopRunning(_ recorder: AVMixerRecorder) {
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
            return try AVAssetWriter(outputURL: url, fileType: AVFileTypeMPEG4)
        } catch {
            logger.warning("create an AVAssetWriter")
        }
        return nil
    }
}
