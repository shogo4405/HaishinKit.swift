import AudioToolbox

extension AudioConverter {
    public enum Destination {
        case aac
        case pcm

        var formatID: AudioFormatID {
            switch self {
            case .aac:
                return kAudioFormatMPEG4AAC
            case .pcm:
                return kAudioFormatLinearPCM
            }
        }

        var formatFlags: UInt32 {
            switch self {
            case .aac:
                return UInt32(MPEG4ObjectID.AAC_LC.rawValue)
            case .pcm:
                return kAudioFormatFlagIsNonInterleaved | kAudioFormatFlagIsPacked | kAudioFormatFlagIsFloat
            }
        }

        var framesPerPacket: UInt32 {
            switch self {
            case .aac:
                return 1024
            case .pcm:
                return 1
            }
        }

        var packetSize: UInt32 {
            switch self {
            case .aac:
                return 1
            case .pcm:
                return 1024
            }
        }

        var bitsPerChannel: UInt32 {
            switch self {
            case .aac:
                return 0
            case .pcm:
                return 32
            }
        }

        var bytesPerPacket: UInt32 {
            switch self {
            case .aac:
                return 0
            case .pcm:
                return (bitsPerChannel / 8)
            }
        }

        var bytesPerFrame: UInt32 {
            switch self {
            case .aac:
                return 0
            case .pcm:
                return (bitsPerChannel / 8)
            }
        }

        var inClassDescriptions: [AudioClassDescription] {
            switch self {
            case .aac:
                #if os(iOS)
                return [
                    AudioClassDescription(mType: kAudioEncoderComponentType, mSubType: kAudioFormatMPEG4AAC, mManufacturer: kAppleSoftwareAudioCodecManufacturer),
                    AudioClassDescription(mType: kAudioEncoderComponentType, mSubType: kAudioFormatMPEG4AAC, mManufacturer: kAppleHardwareAudioCodecManufacturer)
                ]
                #else
                return []
                #endif
            case .pcm:
                return []
            }
        }

        func maximumBuffers(_ channel: UInt32) -> Int {
            switch self {
            case .aac:
                return 1
            case .pcm:
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
