import Foundation
import AVFoundation
import CoreMedia

final class MP4Encoder: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    static let defaultDuration:Int64 = 2
    static let defaultWidth:NSNumber = 480
    static let defaultHeight:NSNumber = 270
    static let defaultAudioBitrate:NSNumber = 32 * 1024
    static let defaultVideoBitrate:NSNumber = 16 * 10 * 1024

    static let defaultAudioSettings:Dictionary<String, AnyObject> = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVNumberOfChannelsKey: 1,
        AVEncoderBitRateKey: MP4Encoder.defaultAudioBitrate,
        AVSampleRateKey: 44100
    ]

    static let defaultVideoSettings:Dictionary<String, AnyObject> = [
        AVVideoCodecKey: AVVideoCodecH264,
        AVVideoWidthKey: MP4Encoder.defaultWidth,
        AVVideoHeightKey: MP4Encoder.defaultHeight,
        AVVideoCompressionPropertiesKey: [
            AVVideoProfileLevelKey: AVVideoProfileLevelH264Baseline30,
            AVVideoAverageBitRateKey: MP4Encoder.defaultVideoBitrate
        ]
    ]

    var isEmpty:Bool {
        return files.isEmpty
    }

    var duration:Int64 = MP4Encoder.defaultDuration
    var recording:Bool = false
    var expectsMediaDataInRealTime:Bool = true
    var audioSettings:Dictionary<String, AnyObject> = MP4Encoder.defaultAudioSettings
    var videoSettings:Dictionary<String, AnyObject> = MP4Encoder.defaultVideoSettings
    let captureQueue:dispatch_queue_t = dispatch_queue_create("com.github.shogo4405.lf.MP4Encoder.capture", DISPATCH_QUEUE_SERIAL)

    private var files:[NSURL] = []
    private var time:CMTime = kCMTimeZero
    private var rotateTime:CMTime = CMTimeAdd(kCMTimeZero, CMTimeMake(MP4Encoder.defaultDuration, 1))
    private var writer:AVAssetWriter? = nil
    private var writers:Dictionary<NSURL, AVAssetWriter> = [:]
    private let lockQueue:dispatch_queue_t = dispatch_queue_create("com.github.shogo4405.lf.MP4Encoder.lock", DISPATCH_QUEUE_SERIAL)

    override init() {
        super.init()
    }

    func shift() -> NSURL? {
        var url:NSURL? = nil
        dispatch_sync(lockQueue) {
            if (!self.files.isEmpty) {
                url = self.files.removeAtIndex(self.files.startIndex)
            }
        }
        return url
    }

    func push(file:NSURL) {
        dispatch_async(lockQueue) {
            self.files.append(file)
        }
    }

    func remove(url:NSURL) -> Bool{
        var error:NSError?
        let removed:Bool = NSFileManager.defaultManager().removeItemAtURL(url, error: &error)
        if (!removed) {
            print(error!)
        }
        return removed
    }

    func clear() {
        dispatch_sync(lockQueue) {
            self.files.removeAll(keepCapacity: false)
            self.writers.removeAll(keepCapacity: false)
            self.writer = nil
        }
    }

    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        if (!recording || CMSampleBufferDataIsReady(sampleBuffer) == 0) {
            return
        }

        var mediaType:String = AVMediaTypeAudio
        if (captureOutput is AVCaptureVideoDataOutput) {
            mediaType = AVMediaTypeVideo
        }

        time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        dispatch_sync(lockQueue) {
            if (self.rotateTime.value <= self.time.value) {
                self.rotateAssetWriter(self.time)
            }
        }
        
        for input in writer!.inputs {
            let input:AVAssetWriterInput = input as! AVAssetWriterInput
            if (input.mediaType != mediaType) {
                continue
            }
            if (input.readyForMoreMediaData) {
                input.appendSampleBuffer(sampleBuffer)
            }
        }
    }

    func captureOutput(captureOutput: AVCaptureOutput!, didDropSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
    }

    private func rotateAssetWriter(time:CMTime) {
        rotateTime = CMTimeAdd(time, CMTimeMake(duration, 1))

        var currentWriter:AVAssetWriter? = self.writer

        if (self.writer != nil) {
            let outputURL:NSURL = self.writer!.outputURL
            writers[outputURL] = self.writer
            for input in self.writer!.inputs {
                if let input:AVAssetWriterInput = input as? AVAssetWriterInput {
                    input.markAsFinished()
                }
            }
            self.writer!.finishWritingWithCompletionHandler {
                self.onFinishWriting(outputURL)
            }
        }

        let writer:AVAssetWriter = AVAssetWriter(
            URL: createTemporaryURL(),
            fileType: AVFileTypeMPEG4,
            error: nil
        )
        // writer.movieFragmentInterval = CMTimeMake(2, 1)
        writer.addInput(createAudioInput(audioSettings))
        writer.addInput(createVideoInput(videoSettings))
        writer.startWriting()
        writer.startSessionAtSourceTime(time)

        self.writer = writer
    }

    private func createAudioInput(outputSetting:Dictionary<String, AnyObject>) -> AVAssetWriterInput {
        let input:AVAssetWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: outputSetting)
        input.expectsMediaDataInRealTime = expectsMediaDataInRealTime
        return input
    }

    private func createVideoInput(outputSetting:Dictionary<String, AnyObject>) -> AVAssetWriterInput {
        let input:AVAssetWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: outputSetting)
        input.expectsMediaDataInRealTime = expectsMediaDataInRealTime
        return input
    }

    private func createTemporaryURL() -> NSURL {
        let path:String = NSTemporaryDirectory().stringByAppendingPathComponent(NSUUID().UUIDString)
        return NSURL(fileURLWithPath: path)!
    }

    private func onFinishWriting(url:NSURL) {
        dispatch_async(lockQueue) {
            self.files.append(url)
            self.writers[url] = nil
        }
    }
}
