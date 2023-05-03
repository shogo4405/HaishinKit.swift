import AVFoundation

/// The type of flv supports audio codecs.
enum FLVAudioCodec: UInt8 {
    /// The PCM codec.
    case pcm = 0
    /// The ADPCM codec.
    case adpcm = 1
    /// The MP3 codec.
    case mp3 = 2
    /// The PCM little endian codec.
    case pcmle = 3
    /// The Nellymoser 16kHz codec.
    case nellymoser16K = 4
    /// The Nellymoser 8kHz codec.
    case nellymoser8K = 5
    /// The Nellymoser codec.
    case nellymoser = 6
    /// The G.711 A-law codec.
    case g711A = 7
    /// The G.711 mu-law codec.
    case g711MU = 8
    /// The AAC codec.
    case aac = 10
    /// The Speex codec.
    case speex = 11
    /// The MP3 8kHz codec.
    case mp3_8k = 14
    /// The Device-specific sound.
    case device = 15
    /// The undefined codec
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
            return AudioFormatFlags(AudioSpecificConfig.AudioObjectType.aacMain.rawValue)
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
