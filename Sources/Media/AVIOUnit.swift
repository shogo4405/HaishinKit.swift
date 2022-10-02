import AVFAudio
import Foundation

public typealias AVCodecDelegate = AudioCodecDelegate & VideoCodecDelegate

protocol AVIOUnit {
    var mixer: AVMixer? { get set }
}

protocol AVIOUnitEncoding {
    func startEncoding(_ delegate: AVCodecDelegate)
    func stopEncoding()
}

protocol AVIOUnitDecoding {
    func startDecoding(_ audioEngine: AVAudioEngine)
    func stopDecoding()
}
