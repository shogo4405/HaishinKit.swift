import AVFoundation
import Foundation

enum AVAudioFormatFactory {
    static func makeAudioFormat(_ inSourceFormat: inout AudioStreamBasicDescription) -> AVAudioFormat? {
        if inSourceFormat.mFormatID == kAudioFormatLinearPCM && kLinearPCMFormatFlagIsBigEndian == (inSourceFormat.mFormatFlags & kLinearPCMFormatFlagIsBigEndian) {
            // ReplayKit audioApp.
            guard inSourceFormat.mBitsPerChannel == 16 else {
                return nil
            }
            if let layout = Self.makeChannelLayout(inSourceFormat.mChannelsPerFrame) {
                return .init(commonFormat: .pcmFormatInt16, sampleRate: inSourceFormat.mSampleRate, interleaved: true, channelLayout: layout)
            }
            return AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: inSourceFormat.mSampleRate, channels: inSourceFormat.mChannelsPerFrame, interleaved: true)
        }
        if let layout = Self.makeChannelLayout(inSourceFormat.mChannelsPerFrame) {
            return .init(streamDescription: &inSourceFormat, channelLayout: layout)
        }
        return .init(streamDescription: &inSourceFormat)
    }

    private static func makeChannelLayout(_ numberOfChannels: UInt32) -> AVAudioChannelLayout? {
        guard 2 < numberOfChannels else {
            return nil
        }
        return AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_DiscreteInOrder | numberOfChannels)
    }
}
