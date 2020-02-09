import CoreAudio
import Foundation

extension AudioStreamBasicDescription: Equatable {
    public static func == (lhs: AudioStreamBasicDescription, rhs: AudioStreamBasicDescription) -> Bool {
        lhs.mBitsPerChannel == rhs.mBitsPerChannel &&
        lhs.mBytesPerFrame == rhs.mBytesPerFrame &&
        lhs.mBytesPerPacket == rhs.mBytesPerPacket &&
        lhs.mChannelsPerFrame == rhs.mChannelsPerFrame &&
        lhs.mFormatFlags == rhs.mFormatFlags &&
        lhs.mFormatID == rhs.mFormatID &&
        lhs.mFramesPerPacket == rhs.mFramesPerPacket &&
        lhs.mReserved == rhs.mReserved &&
        lhs.mSampleRate == rhs.mSampleRate
    }
}
