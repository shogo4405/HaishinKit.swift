import AVFoundation
import CoreMedia
import Foundation

extension AVAudioTime {
    func makeTime() -> CMTime {
        return .init(value: CMTimeValue(sampleTime), timescale: CMTimeScale(sampleRate))
    }
}
