import AVFoundation
import Foundation

/// An object that apply an audio effect.
open class AudioEffect: NSObject {
    /// Executes to apply an audio effect.
    open func execute(_ buffer: AVAudioBuffer, presentationTimeStamp: CMTime) {
    }
}
