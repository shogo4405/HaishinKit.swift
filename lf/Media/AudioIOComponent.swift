import Foundation
import AVFoundation

final class AudioIOComponent: NSObject {
    var encoder:AACEncoder = AACEncoder()
    let lockQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.AudioIOComponent.lock", DISPATCH_QUEUE_SERIAL
    )
    override init() {
        encoder.lockQueue = lockQueue
    }
}

extension AudioIOComponent: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        encoder.captureOutput(captureOutput, didOutputSampleBuffer: sampleBuffer, fromConnection: connection)
    }
}
