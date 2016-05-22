import Foundation
import AVFoundation

// MARK: Encoder
protocol Encoder: Runnable {
}

// MARK: VideoEncoderDelegate
protocol VideoEncoderDelegate: class {
    func didSetFormatDescription(video formatDescription:CMFormatDescriptionRef?)
    func sampleOutput(video sampleBuffer: CMSampleBuffer)
}

// MARK: VideoDecoderDelegate
protocol VideoDecoderDelegate: class {
    func imageOutput(imageBuffer:CVImageBuffer!, presentationTimeStamp:CMTime, presentationDuration:CMTime)
}

// MARK: AudioEncoderDelegate
protocol AudioEncoderDelegate: class {
    func didSetFormatDescription(audio formatDescription:CMFormatDescriptionRef?)
    func sampleOutput(audio sampleBuffer: CMSampleBuffer)
}

struct DecompressionBuffer {
    var imageBuffer:CVImageBuffer?
    var presentationTimeStamp:CMTime
    var presentationDuration:CMTime
}
