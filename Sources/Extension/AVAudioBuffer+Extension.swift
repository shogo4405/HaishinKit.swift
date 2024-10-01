import AVFoundation

#if hasAttribute(retroactive)
extension AVAudioBuffer: @retroactive @unchecked Sendable {}
#else
extension AVAudioBuffer: @unchecked Sendable {}
#endif
