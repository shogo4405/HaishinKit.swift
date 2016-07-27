import Foundation
import AVFoundation

// MARK: AVMixerRecorderDelegate
public protocol AVMixerRecorderDelegate: class {
    var moviesDirectory:NSURL { get }
    func createWriter(fileName:String?) -> AVAssetWriter?
    func createWriterInputs(outputSettings:[String:[String:AnyObject]?]) -> [String: AVAssetWriterInput]
    func fileRotate(sampleBuffer:CMSampleBuffer, mediaType:String, recorder:AVMixerRecorder)
}

// MARK: -
public class AVMixerRecorder: NSObject {
    static let defaultDelegate:AVMixerRecorderDelegate = DefaultAVMixerRecorderDelegate()

    public static let defaultOutputSettings:[String:[String:AnyObject]?] = [
        AVMediaTypeAudio: [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
        ],
        AVMediaTypeVideo: [
            AVVideoCodecKey: AVVideoCodecH264,
            AVVideoHeightKey: 760,
            AVVideoWidthKey: 1200,
        ],
    ]
    public var writer:AVAssetWriter?
    public var fileName:String?
    public var writerInputs:[String:AVAssetWriterInput] = [:]
    public var outputSettings:[String:[String:AnyObject]?] = AVMixerRecorder.defaultOutputSettings
    public weak var delegate:AVMixerRecorderDelegate? = AVMixerRecorder.defaultDelegate
    public let lockQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.AVMixerRecorder.lock", DISPATCH_QUEUE_SERIAL
    )
    private(set) var running:Bool = false

    final func markAsFinished() {
        for (_, input) in self.writerInputs {
            input.markAsFinished()
        }
    }

    final func appendSampleBuffer(sampleBuffer:CMSampleBuffer, mediaType:String) {
        dispatch_async(lockQueue) {
            guard let writer:AVAssetWriter = self.writer, input:AVAssetWriterInput = self.writerInputs[mediaType]
                where self.running else {
                return
            }
            if let delegate:AVMixerRecorderDelegate = self.delegate {
                delegate.fileRotate(sampleBuffer, mediaType: mediaType, recorder: self)
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
}

// MARK: Runnable
extension AVMixerRecorder: Runnable {
    final func startRunning() {
        dispatch_async(lockQueue) {
            guard !self.running else {
                return
            }
            self.writer = self.delegate?.createWriter(self.fileName)
            if let inputs:[String:AVAssetWriterInput] = self.delegate?.createWriterInputs(self.outputSettings) {
                self.writerInputs = inputs
                for (_, input) in self.writerInputs {
                    self.writer?.addInput(input)
                }
            }
            self.running = true
        }
    }

    final func stopRunning() {
        dispatch_async(lockQueue) {
            guard self.running else {
                return
            }
            self.markAsFinished()
            if let writer:AVAssetWriter = self.writer {
                writer.finishWritingWithCompletionHandler({})
            }
            self.running = false
        }
    }
}

// MARK: -
public class DefaultAVMixerRecorderDelegate: NSObject {
}

// MARK: AVMixerRecorderDelegate
extension DefaultAVMixerRecorderDelegate: AVMixerRecorderDelegate {

    public var moviesDirectory:NSURL {
        return NSURL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.MoviesDirectory, .UserDomainMask, true)[0])
    }

    public func createWriter(fileName: String?) -> AVAssetWriter? {
        do {
            let fullPath:NSURL = moviesDirectory.URLByAppendingPathComponent((fileName ?? NSUUID().UUIDString) + ".mp4")
            return try AVAssetWriter(URL: fullPath, fileType: AVFileTypeMPEG4)
        } catch {
            logger.warning("create an AVAssetWriter")
        }
        return nil
    }

    public func createWriterInputs(outputSettings:[String:[String:AnyObject]?]) -> [String : AVAssetWriterInput] {
        var writerInputs:[String: AVAssetWriterInput] = [:]
        for (key, value) in outputSettings {
            writerInputs[key] = AVAssetWriterInput(mediaType: key, outputSettings: value)
            writerInputs[key]?.expectsMediaDataInRealTime = true
        }
        return writerInputs
    }

    public func fileRotate(sampleBuffer: CMSampleBuffer, mediaType: String, recorder: AVMixerRecorder) {
    }
}
