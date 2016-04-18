import Foundation
import AVFoundation

// MARK: HTTPStream
class HTTPStream {
    private(set) var name:String?
    private var mixer:AVMixer = AVMixer()
    private var tsWriter:TSWriter = TSWriter()
    private let lockQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.HTTPStream.lock", DISPATCH_QUEUE_SERIAL
    )

    func getResource(resourceName:String) -> (MIME, String)? {
        guard let
            name:String = name,
            pathComponents:[String] = NSURL(fileURLWithPath: resourceName).pathComponents
        where
            2 <= pathComponents.count && pathComponents[1] == name else {
            return nil
        }
        let fileName:String = pathComponents[pathComponents.count - 1]
        switch true {
        case fileName == "playlist.m3u8":
            return (MIME.ApplicationXMpegURL, tsWriter.playlist)
        case fileName.containsString(".ts"):
            if let mediaFile:String = tsWriter.getFilePath(fileName) {
                return (MIME.VideoMP2T, mediaFile)
            }
            return nil
        default:
            return nil
        }
    }

    func attachCamera(camera:AVCaptureDevice?) {
        dispatch_async(lockQueue) {
            self.mixer.attachCamera(camera)
            self.mixer.startRunning()
        }
    }

    func publish(name:String?) {
        dispatch_async(lockQueue) {
            if (name == nil) {
                self.name = name
                self.mixer.videoIO.encoder.delegate = nil
                self.mixer.videoIO.encoder.stopRunning()
                self.mixer.videoIO.encoder.delegate = nil
                self.mixer.audioIO.encoder.stopRunning()
                self.tsWriter.stopRunning()
                return
            }
            self.name = name
            self.mixer.videoIO.encoder.delegate = self.tsWriter
            self.mixer.videoIO.encoder.startRunning()
            self.mixer.videoIO.encoder.delegate = self.tsWriter
            self.mixer.audioIO.encoder.startRunning()
            self.tsWriter.startRunning()
        }
    }
}

// MARK: - VideoEncoderDelegate
extension HTTPStream: VideoEncoderDelegate {
    func didSetFormatDescription(video formatDescription: CMFormatDescriptionRef?) {
        tsWriter.didSetFormatDescription(video: formatDescription)
    }
    func sampleOutput(video sampleBuffer: CMSampleBuffer) {
        tsWriter.sampleOutput(video: sampleBuffer)
    }
}
