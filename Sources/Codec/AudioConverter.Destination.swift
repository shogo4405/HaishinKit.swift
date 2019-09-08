import AudioToolbox

extension AudioConverter {
    public enum Destination {
        case AAC
        case PCM

        var formatID: AudioFormatID {
            switch self {
            case .AAC:
                return kAudioFormatMPEG4AAC
            case .PCM:
                return kAudioFormatLinearPCM
            }
        }

        var formatFlags: UInt32 {
            switch self {
            case .AAC:
                return UInt32(MPEG4ObjectID.AAC_LC.rawValue)
            case .PCM:
                return kAudioFormatFlagIsNonInterleaved | kAudioFormatFlagIsPacked | kAudioFormatFlagIsFloat
            }
        }

        var framesPerPacket: UInt32 {
            switch self {
            case .AAC:
                return 1024
            case .PCM:
                return 1
            }
        }

        var packetSize: UInt32 {
            switch self {
            case .AAC:
                return 1
            case .PCM:
                return 1024
            }
        }

        var bitsPerChannel: UInt32 {
            switch self {
            case .AAC:
                return 0
            case .PCM:
                return 32
            }
        }

        var bytesPerPacket: UInt32 {
            switch self {
            case .AAC:
                return 0
            case .PCM:
                return (bitsPerChannel / 8)
            }
        }

        var bytesPerFrame: UInt32 {
            switch self {
            case .AAC:
                return 0
            case .PCM:
                return (bitsPerChannel / 8)
            }
        }

        var inClassDescriptions: [AudioClassDescription] {
            switch self {
            case .AAC:
                #if os(iOS)
                return [
                    AudioClassDescription(mType: kAudioEncoderComponentType, mSubType: kAudioFormatMPEG4AAC, mManufacturer: kAppleSoftwareAudioCodecManufacturer),
                    AudioClassDescription(mType: kAudioEncoderComponentType, mSubType: kAudioFormatMPEG4AAC, mManufacturer: kAppleHardwareAudioCodecManufacturer)
                ]
                #else
                return []
                #endif
            case .PCM:
                return []
            }
        }

        func mamimumBuffers(_ channel: UInt32) -> Int {
            switch self {
            case .AAC:
                return 1
            case .PCM:
                return Int(channel)
            }
        }

        func audioStreamBasicDescription(_ inSourceFormat: AudioStreamBasicDescription?, sampleRate: Double, channels: UInt32) -> AudioStreamBasicDescription? {
            guard let inSourceFormat = inSourceFormat else { return nil }
            let destinationChannels: UInt32 = (channels == 0) ? inSourceFormat.mChannelsPerFrame : channels
            return AudioStreamBasicDescription(
                mSampleRate: sampleRate == 0 ? inSourceFormat.mSampleRate : sampleRate,
                mFormatID: formatID,
                mFormatFlags: formatFlags,
                mBytesPerPacket: bytesPerPacket,
                mFramesPerPacket: framesPerPacket,
                mBytesPerFrame: bytesPerFrame,
                mChannelsPerFrame: destinationChannels,
                mBitsPerChannel: bitsPerChannel,
                mReserved: 0
            )
        }
    }
}
