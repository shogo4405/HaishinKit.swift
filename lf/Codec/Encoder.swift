import Foundation
import AVFoundation

protocol Encoder {
    func dispose()
}

protocol VideoEncoderDelegate: class {
    func didSetFormatDescription(video formatDescription:CMFormatDescriptionRef?)
    func sampleOuput(video sampleBuffer: CMSampleBuffer)
}

protocol AudioEncoderDelegate: class {
    func didSetFormatDescription(audio formatDescription:CMFormatDescriptionRef?)
    func sampleOuput(audio sampleBuffer: CMSampleBuffer)
}
