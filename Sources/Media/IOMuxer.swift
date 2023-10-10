import AVFoundation
import Foundation

public protocol IOMuxer: AnyObject {
    var audioFormat: AVAudioFormat? { get set }
    var videoFormat: CMFormatDescription? { get set }

    func append(_ audioBuffer: AVAudioCompressedBuffer, when: AVAudioTime)
    func append(_ sampleBuffer: CMSampleBuffer)
}
