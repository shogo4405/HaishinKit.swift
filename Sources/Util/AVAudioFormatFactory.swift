import AVFoundation
import Foundation

enum AVAudioFormatFactory {
    static func makeAudioFormat(_ inSourceFormat: inout AudioStreamBasicDescription) -> AVAudioFormat? {
        if inSourceFormat.mFormatID == kAudioFormatLinearPCM && kLinearPCMFormatFlagIsBigEndian == (inSourceFormat.mFormatFlags & kLinearPCMFormatFlagIsBigEndian) {
            // ReplayKit audioApp.
            guard inSourceFormat.mBitsPerChannel == 16 else {
                return nil
            }
            let interleaved = !((inSourceFormat.mFormatFlags & kLinearPCMFormatFlagIsNonInterleaved) == kLinearPCMFormatFlagIsNonInterleaved)
            if let channelLayout = Self.makeChannelLayout(inSourceFormat.mChannelsPerFrame) {
                return .init(
                    commonFormat: .pcmFormatInt16,
                    sampleRate: inSourceFormat.mSampleRate,
                    interleaved: interleaved,
                    channelLayout: channelLayout
                )
            }
            return .init(
                commonFormat: .pcmFormatInt16,
                sampleRate: inSourceFormat.mSampleRate,
                channels: inSourceFormat.mChannelsPerFrame,
                interleaved: interleaved
            )
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
        switch numberOfChannels {
        case 4:
            return AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_AudioUnit_4)
        case 5:
            return AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_AudioUnit_5)
        case 6:
            return AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_AudioUnit_6)
        case 8:
            return AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_AudioUnit_8)
        default:
            return AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_DiscreteInOrder | numberOfChannels)
        }
    }
}
