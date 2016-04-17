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
                self.mixer.videoIO.encoder.stopRunning()
                self.mixer.audioIO.encoder.stopRunning()
                self.tsWriter.stopRunning()
                return
            }
            self.name = name
            self.mixer.videoIO.encoder.startRunning()
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
