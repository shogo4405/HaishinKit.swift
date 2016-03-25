import Foundation
import AVFoundation

protocol Encoder: Runnable {
}

protocol VideoEncoderDelegate: class {
    func didSetFormatDescription(video formatDescription:CMFormatDescriptionRef?)
    func sampleOutput(video sampleBuffer: CMSampleBuffer)
}

protocol VideoDecoderDelegate: class {
    func imageOutput(imageBuffer:CVImageBuffer,  presentationTimeStamp:CMTime, presentationDuration:CMTime)
}

protocol AudioEncoderDelegate: class {
    func didSetFormatDescription(audio formatDescription:CMFormatDescriptionRef?)
    func sampleOutput(audio sampleBuffer: CMSampleBuffer)
}
