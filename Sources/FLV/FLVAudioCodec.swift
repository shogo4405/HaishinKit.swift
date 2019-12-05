import AVFoundation

public enum FLVAudioCodec: UInt8 {
    case pcm = 0
    case adpcm = 1
    case mp3 = 2
    case pcmle = 3
    case nellymoser16K = 4
    case nellymoser8K = 5
    case nellymoser = 6
    case g711A = 7
    case g711MU = 8
    case aac = 10
    case speex = 11
    case mp3_8k = 14
    case unknown = 0xFF

    var isSupported: Bool {
        switch self {
        case .aac:
            return true
        default:
            return false
        }
    }

    var formatID: AudioFormatID {
        switch self {
        case .pcm:
            return kAudioFormatLinearPCM
        case .mp3:
            return kAudioFormatMPEGLayer3
        case .pcmle:
            return kAudioFormatLinearPCM
        case .aac:
            return kAudioFormatMPEG4AAC
        case .mp3_8k:
            return kAudioFormatMPEGLayer3
        default:
            return 0
        }
    }

    var formatFlags: AudioFormatFlags {
        switch self {
        case .aac:
            return AudioFormatFlags(AudioObjectType.aacMain.rawValue)
        default:
            return 0
        }
    }

    var headerSize: Int {
        switch self {
        case .aac:
            return 2
        default:
            return 1
        }
    }

    func audioStreamBasicDescription(_ rate: FLVSoundRate, size: FLVSoundSize, type: FLVSoundType) -> AudioStreamBasicDescription? {
        guard isSupported else {
            return nil
        }
        return AudioStreamBasicDescription(
            mSampleRate: rate.floatValue,
            mFormatID: formatID,
            mFormatFlags: formatFlags,
            mBytesPerPacket: 0,
            mFramesPerPacket: 1024,
            mBytesPerFrame: 0,
            mChannelsPerFrame: type == .stereo ? 2 : 1,
            mBitsPerChannel: 0,
            mReserved: 0
        )
    }
}
