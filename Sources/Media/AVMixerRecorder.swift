import Foundation
import AVFoundation
#if os(iOS)
import AssetsLibrary
#endif

// MARK: AVMixerRecorderDelegate
public protocol AVMixerRecorderDelegate: class {
    var moviesDirectory:NSURL { get }
    func rotateFile(recorder:AVMixerRecorder, sampleBuffer:CMSampleBuffer, mediaType:String)
    func getWriterInput(recorder:AVMixerRecorder, mediaType:String, sourceFormatHint:CMFormatDescription?) -> AVAssetWriterInput?
    func didStartRunning(recorder: AVMixerRecorder)
    func didStopRunning(recorder: AVMixerRecorder)
    func didFinishWriting(recorder: AVMixerRecorder)
}

// MARK: -
public class AVMixerRecorder: NSObject {

    public static let defaultOutputSettings:[String:[String:AnyObject]] = [
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

    public var writer:AVAssetWriter?
    public var fileName:String?
    public var writerInputs:[String:AVAssetWriterInput] = [:]
    public var outputSettings:[String:[String:AnyObject]] = AVMixerRecorder.defaultOutputSettings
    public var delegate:AVMixerRecorderDelegate?
    public let lockQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.AVMixerRecorder.lock", DISPATCH_QUEUE_SERIAL
    )
    private(set) var running:Bool = false

    public override init() {
        super.init()
        delegate = DefaultAVMixerRecorderDelegate()
    }

    final func appendSampleBuffer(sampleBuffer:CMSampleBuffer, mediaType:String) {
        dispatch_async(lockQueue) {

            guard let delegate:AVMixerRecorderDelegate = self.delegate where self.running else {
                return
            }

            delegate.rotateFile(self, sampleBuffer: sampleBuffer, mediaType: mediaType)

            guard let
                writer:AVAssetWriter = self.writer,
                input:AVAssetWriterInput = delegate.getWriterInput(self, mediaType: mediaType, sourceFormatHint: sampleBuffer.formatDescription) else {
                return
            }

            switch writer.status {
            case .Unknown:
                writer.startWriting()
                writer.startSessionAtSourceTime(sampleBuffer.presentationTimeStamp)
            default:
                break
            }
            if (input.readyForMoreMediaData) {
                input.appendSampleBuffer(sampleBuffer)
            }
        }
    }

    func finishWriting() {
        for (_, input) in writerInputs {
            input.markAsFinished()
        }
        writer?.finishWritingWithCompletionHandler {
            self.delegate?.didFinishWriting(self)
        }
        writer = nil
        writerInputs = [:]
    }
}

// MARK: Runnable
extension AVMixerRecorder: Runnable {
    final func startRunning() {
        dispatch_async(lockQueue) {
            guard !self.running else {
                return
            }
            self.running = true
            self.delegate?.didStartRunning(self)
        }
    }

    final func stopRunning() {
        dispatch_async(lockQueue) {
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
public class DefaultAVMixerRecorderDelegate: NSObject {
    public var duration:Int64 = 0
    public var dateFormat:String = "-yyyyMMdd-HHmmss"
    private var rotateTime:CMTime = kCMTimeZero
    private var clockReference:String = AVMediaTypeVideo

    #if os(OSX)
    public lazy var moviesDirectory:NSURL = {
        return NSURL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.MoviesDirectory, .UserDomainMask, true)[0])
    }()
    #else
    public lazy var moviesDirectory:NSURL = {
        return NSURL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0])
    }()
    #endif
}

// MARK: AVMixerRecorderDelegate
extension DefaultAVMixerRecorderDelegate: AVMixerRecorderDelegate {

    public func rotateFile(recorder:AVMixerRecorder, sampleBuffer:CMSampleBuffer, mediaType:String) {
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

    public func getWriterInput(recorder:AVMixerRecorder, mediaType:String, sourceFormatHint:CMFormatDescription?) -> AVAssetWriterInput? {
        guard recorder.writerInputs[mediaType] == nil else {
            return recorder.writerInputs[mediaType]
        }
        var outputSettings:[String:AnyObject] = [:]
        if let defaultOutputSettings:[String:AnyObject] = recorder.outputSettings[mediaType] {
            if (mediaType == AVMediaTypeAudio) {
                let inSourceFormat:AudioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(sourceFormatHint!).memory
                for (key, value) in defaultOutputSettings {
                    switch key {
                    case AVSampleRateKey:
                        outputSettings[key] = value as! NSObject == 0 ? inSourceFormat.mSampleRate : value
                    case AVNumberOfChannelsKey:
                        outputSettings[key] = value as! NSObject == 0 ? Int(inSourceFormat.mChannelsPerFrame) : value
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
                        outputSettings[key] = value as! NSObject == 0 ? Int(dimensions.height) : value
                    case AVVideoWidthKey:
                        outputSettings[key] = value as! NSObject == 0 ? Int(dimensions.width) : value
                    default:
                        outputSettings[key] = value
                    }
                }
            }
        }
        var input:AVAssetWriterInput?
        input = AVAssetWriterInput(mediaType: mediaType, outputSettings: outputSettings, sourceFormatHint: sourceFormatHint)
        recorder.writerInputs[mediaType] = input
        recorder.writer?.addInput(input!)
        return input
    }

    public func didFinishWriting(recorder:AVMixerRecorder) {
    #if os(iOS)
        guard let writer:AVAssetWriter = recorder.writer else {
            return
        }
        ALAssetsLibrary().writeVideoAtPathToSavedPhotosAlbum(writer.outputURL, completionBlock: nil)
        do {
            try NSFileManager.defaultManager().removeItemAtURL(writer.outputURL)
        } catch let error as NSError {
            logger.error("\(error)")
        }
    #endif
    }

    public func didStartRunning(recorder: AVMixerRecorder) {
    }

    public func didStopRunning(recorder: AVMixerRecorder) {
        rotateTime = kCMTimeZero
    }

    func createWriter(fileName: String?) -> AVAssetWriter? {
        do {
            let dateFormatter:NSDateFormatter = NSDateFormatter()
            dateFormatter.locale = NSLocale(localeIdentifier: "en_US")
            dateFormatter.dateFormat = dateFormat
            var fileComponent:String? = nil
            if var fileName:String = fileName {
                if let q:String.CharacterView.Index = fileName.characters.indexOf("?") {
                    fileName.removeRange(q..<fileName.characters.endIndex)
                }
                fileComponent = fileName + dateFormatter.stringFromDate(NSDate())
            }
            let url:NSURL = moviesDirectory.URLByAppendingPathComponent((fileComponent ?? NSUUID().UUIDString) + ".mp4")
            logger.info("\(url)")
            return try AVAssetWriter(URL: url, fileType: AVFileTypeMPEG4)
        } catch {
            logger.warning("create an AVAssetWriter")
        }
        return nil
    }
}
