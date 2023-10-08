import AVFoundation
import Foundation

extension CMTime {
    func makeAudioTime() -> AVAudioTime {
        return .init(sampleTime: value, atRate: Double(timescale))
    }
}
