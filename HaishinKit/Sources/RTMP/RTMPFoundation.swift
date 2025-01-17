import AVFoundation

/// The type of flv supports aac packet types.
enum RTMPAACPacketType: UInt8 {
    /// The sequence data.
    case seq = 0
    /// The raw data.
    case raw = 1
}

/// The type of flv supports avc packet types.
enum RTMPAVCPacketType: UInt8 {
    /// The sequence data.
    case seq = 0
    /// The NAL unit data.
    case nal = 1
    /// The end of stream data.
    case eos = 2
}

/// The type of flv supports audio codecs.
enum RTMPAudioCodec: UInt8 {
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
    /// The signal FOURCC mode.
    case exheader = 9
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

    func audioStreamBasicDescription(_ payload: Data) -> AudioStreamBasicDescription? {
        guard isSupported, !payload.isEmpty else {
            return nil
        }
        guard
            let soundRate = RTMPSoundRate(rawValue: (payload[0] & 0b00001100) >> 2),
            let soundType = RTMPSoundType(rawValue: (payload[0] & 0b00000001)) else {
            return nil
        }
        return AudioStreamBasicDescription(
            mSampleRate: soundRate.floatValue,
            mFormatID: formatID,
            mFormatFlags: formatFlags,
            mBytesPerPacket: 0,
            mFramesPerPacket: 1024,
            mBytesPerFrame: 0,
            mChannelsPerFrame: soundType == .stereo ? 2 : 1,
            mBitsPerChannel: 0,
            mReserved: 0
        )
    }
}

/// The type of flv supports video frame types.
enum RTMPFrameType: UInt8 {
    /// The keyframe.
    case key = 1
    /// The inter frame.
    case inter = 2
    /// The disposable inter frame.
    case disposable = 3
    /// The generated keydrame.
    case generated = 4
    /// The video info or command frame.
    case command = 5
}

enum RTMPSoundRate: UInt8 {
    /// The sound rate of  5,500.0kHz.
    case kHz5_5 = 0
    /// Ths sound rate of 11,000.0kHz.
    case kHz11 = 1
    /// The sound rate of 22,050.0kHz.
    case kHz22 = 2
    /// Ths sound rate of 44,100.0kHz.
    case kHz44 = 3

    /// The float typed value.
    var floatValue: Float64 {
        switch self {
        case .kHz5_5:
            return 5500
        case .kHz11:
            return 11025
        case .kHz22:
            return 22050
        case .kHz44:
            return 44100
        }
    }
}

/// The type of flv supports audio sound size.
enum RTMPSoundSize: UInt8 {
    /// The 8bit sound.
    case snd8bit = 0
    /// The 16bit sound.
    case snd16bit = 1
}

/// The type of flv supports audio sound channel type..
enum RTMPSoundType: UInt8 {
    /// The mono sound.
    case mono = 0
    /// The stereo sound.
    case stereo = 1
}

/// The type of flv tag.
enum RTMPTagType: UInt8 {
    /// The Audio tag,
    case audio = 8
    /// The Video tag.
    case video = 9
    /// The Data tag.
    case data = 18

    var streamId: UInt16 {
        switch self {
        case .audio, .video:
            return UInt16(rawValue)
        case .data:
            return 0
        }
    }

    var headerSize: Int {
        switch self {
        case .audio:
            return 2
        case .video:
            return 5
        case .data:
            return 0
        }
    }
}

/// The type of flv supports video codecs.
enum RTMPVideoCodec: UInt8 {
    /// The JPEG codec.
    case jpeg = 1
    /// The Sorenson H263 codec.
    case sorensonH263 = 2
    /// The Screen video codec.
    case screen1 = 3
    /// The On2 VP6 codec.
    case on2VP6 = 4
    /// The On2 VP6 with alpha channel codec.
    case on2VP6Alpha = 5
    /// The Screen video version2 codec.
    case screen2 = 6
    /// The AVC codec.
    case avc = 7
    /// The unknown codec.
    case unknown = 0xFF

    var isSupported: Bool {
        switch self {
        case .jpeg:
            return false
        case .sorensonH263:
            return false
        case .screen1:
            return false
        case .on2VP6:
            return false
        case .on2VP6Alpha:
            return false
        case .screen2:
            return false
        case .avc:
            return true
        case .unknown:
            return false
        }
    }
}
