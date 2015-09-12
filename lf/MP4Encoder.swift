import Foundation
import AVFoundation

protocol MP4EncoderDelegate: class {
    func encoderOnFinishWriting(encoder:MP4Encoder, outputURL:NSURL)
}

final class AVAssetWriterComponent {
    var writer:AVAssetWriter!
    var video:AVAssetWriterInput!
    var audio:AVAssetWriterInput!

    init (expectsMediaDataInRealTime:Bool, audioSettings:[String:AnyObject], videoSettings:[String:AnyObject]) {
        do {
            writer = try AVAssetWriter(URL: MP4Encoder.createTemporaryURL(), fileType: AVFileTypeMPEG4)

            audio = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: audioSettings)
            audio.expectsMediaDataInRealTime = expectsMediaDataInRealTime
            writer.addInput(audio)
            
            video = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoSettings)
            video.expectsMediaDataInRealTime = expectsMediaDataInRealTime
            writer.addInput(video)
            
            writer.startWriting()
            writer.startSessionAtSourceTime(kCMTimeZero)
        } catch let error as NSError {
            print(error)
        }
    }

    func markAsFinished() {
        audio.markAsFinished()
        video.markAsFinished()
    }
}

final class MP4Encoder: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    static let defaultDuration:Int64 = 2
    static let defaultWidth:NSNumber = 480
    static let defaultHeight:NSNumber = 270
    static let defaultChannels:NSNumber = 1
    static let defaultSampleRate:NSNumber = 44100
    static let defaultAudioBitrate:NSNumber = 32 * 1024
    static let defaultVideoBitrate:NSNumber = 16 * 10 * 1024

    static let defaultAudioSettings:[String:AnyObject] = [
        AVFormatIDKey: NSNumber(unsignedInt: kAudioFormatMPEG4AAC),
        AVNumberOfChannelsKey: MP4Encoder.defaultChannels,
        AVEncoderBitRateKey: MP4Encoder.defaultAudioBitrate,
        AVSampleRateKey: MP4Encoder.defaultSampleRate
    ]

    static let defaultVideoSettings:[String:AnyObject] = [
        AVVideoCodecKey: AVVideoCodecH264,
        AVVideoWidthKey: MP4Encoder.defaultWidth,
        AVVideoHeightKey: MP4Encoder.defaultHeight,
        AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill,
        AVVideoCompressionPropertiesKey: [
            AVVideoMaxKeyFrameIntervalDurationKey: NSNumber(longLong: MP4Encoder.defaultDuration),
            AVVideoProfileLevelKey: AVVideoProfileLevelH264Baseline30,
            AVVideoAverageBitRateKey: MP4Encoder.defaultVideoBitrate
        ]
    ]

    private static func createTemporaryURL() -> NSURL {
        return NSURL(fileURLWithPath: NSTemporaryDirectory()).URLByAppendingPathComponent(NSUUID().UUIDString + ".mp4")
        
    }

    weak var delegate:MP4EncoderDelegate? = nil
    var duration:Int64 = MP4Encoder.defaultDuration
    var recording:Bool = false
    var expectsMediaDataInRealTime:Bool = true
    var audioSettings:[String:AnyObject] = MP4Encoder.defaultAudioSettings
    var videoSettings:[String:AnyObject] = MP4Encoder.defaultVideoSettings
    let audioQueue:dispatch_queue_t = dispatch_queue_create("com.github.shogo4405.lf.MP4Encoder.audio", DISPATCH_QUEUE_SERIAL)
    let videoQueue:dispatch_queue_t = dispatch_queue_create("com.github.shogo4405.lf.MP4Encoder.video", DISPATCH_QUEUE_SERIAL)

    private var rotateTime:CMTime = CMTimeAdd(kCMTimeZero, CMTimeMake(MP4Encoder.defaultDuration, 1))
    private var component:AVAssetWriterComponent? = nil
    private var components:[NSURL:AVAssetWriterComponent] = [:]
    private let lockQueue:dispatch_queue_t = dispatch_queue_create("com.github.shogo4405.lf.MP4Encoder.lock", DISPATCH_QUEUE_SERIAL)

    override init() {
        super.init()
    }

    func clear() {
        dispatch_sync(lockQueue) {
            self.components.removeAll(keepCapacity: false)
            self.component = nil
        }
    }

    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {

        if (!recording || !CMSampleBufferDataIsReady(sampleBuffer)) {
            return
        }

        let mediaType:String = captureOutput is AVCaptureAudioDataOutput ? AVMediaTypeAudio : AVMediaTypeVideo
        let timestamp:CMTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        if (mediaType == AVMediaTypeVideo && rotateTime.value <= timestamp.value) {
            rotateComponent(timestamp, mediaType: mediaType)
        }

        if (component != nil) {
            switch mediaType {
            case AVMediaTypeAudio:
                onAudioSampleBuffer(sampleBuffer)
            case AVMediaTypeVideo:
                onVideoSampleBuffer(sampleBuffer)
            default:
                break
            }
        }
    }

    func captureOutput(captureOutput: AVCaptureOutput!, didDropSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
    }

    func onAudioSampleBuffer(sampleBuffer:CMSampleBufferRef) {
        if (component!.audio.readyForMoreMediaData) {
            component!.audio.appendSampleBuffer(sampleBuffer)
        }
    }

    func onVideoSampleBuffer(sampleBuffer:CMSampleBufferRef) {
        if (component!.video.readyForMoreMediaData) {
            component!.video.appendSampleBuffer(sampleBuffer)
        }
    }

    private func rotateComponent(timestamp:CMTime, mediaType:String) {
        dispatch_suspend(mediaType == AVMediaTypeAudio ? videoQueue : audioQueue)
        rotateTime = CMTimeAdd(timestamp, CMTimeMake(duration, 1))
        let component:AVAssetWriterComponent? = self.component
        self.component = AVAssetWriterComponent(expectsMediaDataInRealTime: expectsMediaDataInRealTime, audioSettings: audioSettings, videoSettings: videoSettings)
        dispatch_resume(mediaType == AVMediaTypeAudio ? videoQueue : audioQueue)

        if (component != nil) {
            let outputURL:NSURL = component!.writer.outputURL
            components[outputURL] = component
            component!.markAsFinished()
            component!.writer.finishWritingWithCompletionHandler {
                self.onFinishWriting(outputURL)
            }
        }
    }

    private func onFinishWriting(outputURL:NSURL) {
        dispatch_async(lockQueue) {
            self.components.removeValueForKey(outputURL)
            self.delegate?.encoderOnFinishWriting(self , outputURL: outputURL)
        }
    }
}
