import AVFoundation
import Foundation

open class AudioEffect: NSObject {
    open func execute(_ buffer: UnsafeMutableAudioBufferListPointer?, format: AudioStreamBasicDescription?) {
    }
}
