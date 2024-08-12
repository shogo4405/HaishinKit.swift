import AVFoundation

public protocol IOMixerOutput: AnyObject, Sendable {
    func mixer(_ mixer: IOMixer, track: UInt8, didOutput sampleBuffer: CMSampleBuffer)
    func mixer(_ mixer: IOMixer, track: UInt8, didOutput buffer: AVAudioPCMBuffer, when: AVAudioTime)
}
