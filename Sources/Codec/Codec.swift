import Foundation
import AVFoundation


// MARK: VideoDecoderDelegate
protocol VideoDecoderDelegate: class {
    func sampleOutput(video sampleBuffer: CMSampleBuffer)
}

// MARK: AudioEncoderDelegate
protocol AudioEncoderDelegate: class {
    func didSetFormatDescription(audio formatDescription:CMFormatDescriptionRef?)
    func sampleOutput(audio sampleBuffer: CMSampleBuffer)
}
