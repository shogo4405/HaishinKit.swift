import AVFoundation
import CoreMedia
import Foundation

extension AVAudioTime {
    static let zero = AVAudioTime(hostTime: 0)

    func makeTime() -> CMTime {
        return .init(value: sampleTime, timescale: CMTimeScale(sampleRate))
    }
}
