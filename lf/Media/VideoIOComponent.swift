import Foundation
import AVFoundation

protocol VideoIOComponentDelegate: class {
    func didEffect(sampleBuffer: CMSampleBuffer!)
}

final class VideoIOComponent: NSObject {
    var delegate:VideoIOComponentDelegate?
    var encoder:AVCEncoder = AVCEncoder()
    let lockQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.VideoIOComponent.lock", DISPATCH_QUEUE_SERIAL
    )
    private var effects:[IEffect] = []

    func effect(sampleBuffer: CMSampleBuffer!) {
        for effect in effects {
            effect.execute(sampleBuffer)
        }
        delegate?.didEffect(sampleBuffer)
    }

    func registerEffect(effect:IEffect) {
    }

    func unregisterEffect(effect:IEffect) {
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension VideoIOComponent: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        effect(sampleBuffer)
        if let image:CVImageBufferRef = CMSampleBufferGetImageBuffer(sampleBuffer) {
            encoder.encodeImageBuffer(image,
                presentationTimeStamp: CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
                duration: CMSampleBufferGetDuration(sampleBuffer)
            )
        }
    }
}

// MARK: - ScreenCaptureOutputPixelBufferDelegate
extension VideoIOComponent: ScreenCaptureOutputPixelBufferDelegate {
    func pixelBufferOutput(pixelBuffer:CVPixelBufferRef, timestamp:CMTime) {
        encoder.encodeImageBuffer(pixelBuffer,
            presentationTimeStamp: timestamp,
            duration: timestamp
        )
    }
}
