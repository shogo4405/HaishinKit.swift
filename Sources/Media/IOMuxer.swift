import AVFoundation
import Foundation

public protocol IOMuxer: Running, AnyObject {
    var audioFormat: AVAudioFormat? { get set }
    var videoFormat: CMFormatDescription? { get set }

    func append(_ audioBuffer: AVAudioBuffer, when: AVAudioTime)
    func append(_ sampleBuffer: CMSampleBuffer)
}
