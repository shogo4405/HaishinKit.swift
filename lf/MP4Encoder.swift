import Foundation
import AVFoundation

protocol MP4EncoderDelegate: class {
    func encoderOnFinishWriting(encoder:MP4Encoder, outputURL:NSURL)
}

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
            AVVideoMaxKeyFrameIntervalDurationKey: NSNumber(longLong: MP4Encoder.defaultDuration),
            AVVideoProfileLevelKey: AVVideoProfileLevelH264Baseline30,
            AVVideoAverageBitRateKey: MP4Encoder.defaultVideoBitrate
        ]
    ]

    private static func createTemporaryURL() -> NSURL {
        return NSURL(fileURLWithPath: NSTemporaryDirectory().stringByAppendingPathComponent(NSUUID().UUIDString + ".mp4"))!
    }

    weak var delegate:MP4EncoderDelegate? = nil
    var duration:Int64 = MP4Encoder.defaultDuration
    var recording:Bool = false
    var expectsMediaDataInRealTime:Bool = true
    var audioSettings:Dictionary<String, AnyObject> = MP4Encoder.defaultAudioSettings
    var videoSettings:Dictionary<String, AnyObject> = MP4Encoder.defaultVideoSettings
    let audioQueue:dispatch_queue_t = dispatch_queue_create("com.github.shogo4405.lf.MP4Encoder.audio", DISPATCH_QUEUE_SERIAL)
    let videoQueue:dispatch_queue_t = dispatch_queue_create("com.github.shogo4405.lf.MP4Encoder.video", DISPATCH_QUEUE_SERIAL)

    private var rotateTime:CMTime = CMTimeAdd(kCMTimeZero, CMTimeMake(MP4Encoder.defaultDuration, 1))
    private var writer:AVAssetWriter? = nil
    private var writers:Dictionary<NSURL, AVAssetWriter> = [:]
    private let lockQueue:dispatch_queue_t = dispatch_queue_create("com.github.shogo4405.lf.MP4Encoder.lock", DISPATCH_QUEUE_SERIAL)

    override init() {
        super.init()
    }

    func clear() {
        dispatch_sync(lockQueue) {
            self.writers.removeAll(keepCapacity: false)
            self.writer = nil
        }
    }

    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {

        if (!recording || CMSampleBufferDataIsReady(sampleBuffer) == 0) {
            return
        }

        let mediaType:String = captureOutput is AVCaptureAudioDataOutput ? AVMediaTypeAudio : AVMediaTypeVideo
        let timestamp:CMTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        if (mediaType == AVMediaTypeVideo && rotateTime.value <= timestamp.value) {
            rotateAssetWriter(timestamp, mediaType: mediaType)
        }

        if (writer != nil) {
            for input in writer!.inputs {
                let input:AVAssetWriterInput = input as! AVAssetWriterInput
                if (input.mediaType == mediaType && input.readyForMoreMediaData) {
                    input.appendSampleBuffer(sampleBuffer)
                }
            }
        }
    }

    func captureOutput(captureOutput: AVCaptureOutput!, didDropSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
    }

    private func rotateAssetWriter(timestamp:CMTime, mediaType:String) {
        dispatch_suspend(mediaType == AVMediaTypeAudio ? videoQueue : audioQueue)
        rotateTime = CMTimeAdd(timestamp, CMTimeMake(duration, 1))
        let writer:AVAssetWriter? = self.writer
        self.writer = createAssetWriter()
        dispatch_resume(mediaType == AVMediaTypeAudio ? videoQueue : audioQueue)

        if (writer != nil) {
            let outputURL:NSURL = writer!.outputURL
            writers[outputURL] = writer
            for input in writer!.inputs {
                if let input:AVAssetWriterInput = input as? AVAssetWriterInput {
                    input.markAsFinished()
                }
            }
            writer!.finishWritingWithCompletionHandler {
                self.onFinishWriting(outputURL)
            }
        }
    }

    private func createAssetWriter() -> AVAssetWriter {
        var error:NSError?
        let writer:AVAssetWriter = AVAssetWriter(
            URL: MP4Encoder.createTemporaryURL(),
            fileType: AVFileTypeMPEG4,
            error: &error
        )

        let audio:AVAssetWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: audioSettings)
        audio.expectsMediaDataInRealTime = expectsMediaDataInRealTime
        writer.addInput(audio)

        let video:AVAssetWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoSettings)
        video.expectsMediaDataInRealTime = expectsMediaDataInRealTime
        writer.addInput(video)

        writer.startWriting()
        writer.startSessionAtSourceTime(kCMTimeZero)

        return writer
    }

    private func onFinishWriting(outputURL:NSURL) {
        dispatch_async(lockQueue) {
            self.writers[outputURL] = nil
            self.delegate?.encoderOnFinishWriting(self , outputURL: outputURL)
        }
    }
}
