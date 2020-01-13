import AVFoundation
/**
 The Audio Specific Config is the global header for MPEG-4 Audio
 
 - seealse:
  - http://wiki.multimedia.cx/index.php?title=MPEG-4_Audio#Audio_Specific_Config
  - http://wiki.multimedia.cx/?title=Understanding_AAC
 */
struct AudioSpecificConfig {
    static let ADTSHeaderSize: Int = 7

    let type: AudioObjectType
    let frequency: SamplingFrequency
    let channel: ChannelConfiguration
    let frameLengthFlag: Bool = false

    var bytes: [UInt8] {
        var bytes: [UInt8] = [UInt8](repeating: 0, count: 2)
        bytes[0] = type.rawValue << 3 | (frequency.rawValue >> 1)
        bytes[1] = (frequency.rawValue & 0x1) << 7 | (channel.rawValue & 0xF) << 3
        return bytes
    }

    init?(bytes: [UInt8]) {
        guard
            let type = AudioObjectType(rawValue: bytes[0] >> 3),
            let frequency = SamplingFrequency(rawValue: (bytes[0] & 0b00000111) << 1 | (bytes[1] >> 7)),
            let channel = ChannelConfiguration(rawValue: (bytes[1] & 0b01111000) >> 3) else {
            return nil
        }
        self.type = type
        self.frequency = frequency
        self.channel = channel
    }

    init(type: AudioObjectType, frequency: SamplingFrequency, channel: ChannelConfiguration) {
        self.type = type
        self.frequency = frequency
        self.channel = channel
    }

    init(formatDescription: CMFormatDescription) {
        let asbd: AudioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)!.pointee
        type = AudioObjectType(objectID: MPEG4ObjectID(rawValue: Int(asbd.mFormatFlags))!)
        frequency = SamplingFrequency(sampleRate: asbd.mSampleRate)
        channel = ChannelConfiguration(rawValue: UInt8(asbd.mChannelsPerFrame))!
    }

    func adts(_ length: Int) -> [UInt8] {
        let size: Int = 7
        let fullSize: Int = size + length
        var adts: [UInt8] = [UInt8](repeating: 0x00, count: size)
        adts[0] = 0xFF
        adts[1] = 0xF9
        adts[2] = (type.rawValue - 1) << 6 | (frequency.rawValue << 2) | (channel.rawValue >> 2)
        adts[3] = (channel.rawValue & 3) << 6 | UInt8(fullSize >> 11)
        adts[4] = UInt8((fullSize & 0x7FF) >> 3)
        adts[5] = ((UInt8(fullSize & 7)) << 5) + 0x1F
        adts[6] = 0xFC
        return adts
    }

    func audioStreamBasicDescription() -> AudioStreamBasicDescription {
        AudioStreamBasicDescription(
            mSampleRate: frequency.sampleRate,
            mFormatID: kAudioFormatMPEG4AAC,
            mFormatFlags: UInt32(type.rawValue),
            mBytesPerPacket: 0,
            mFramesPerPacket: frameLengthFlag ? 960 : 1024,
            mBytesPerFrame: 0,
            mChannelsPerFrame: UInt32(channel.rawValue),
            mBitsPerChannel: 0,
            mReserved: 0
        )
    }
}

extension AudioSpecificConfig: CustomDebugStringConvertible {
    // MARK: CustomDebugStringConvertible
    var debugDescription: String {
        Mirror(reflecting: self).debugDescription
    }
}

// MARK: -
enum AudioObjectType: UInt8 {
    case unknown = 0
    case aacMain = 1
    case aaclc = 2
    case aacssr = 3
    case aacltp = 4
    case aacsbr = 5
    case aacScalable = 6
    case twinqVQ = 7
    case celp = 8
    case hxvc = 9

    init(objectID: MPEG4ObjectID) {
        switch objectID {
        case .aac_Main:
            self = .aacMain
        case .AAC_LC:
            self = .aaclc
        case .AAC_SSR:
            self = .aacssr
        case .AAC_LTP:
            self = .aacltp
        case .AAC_SBR:
            self = .aacsbr
        case .aac_Scalable:
            self = .aacScalable
        case .twinVQ:
            self = .twinqVQ
        case .CELP:
            self = .celp
        case .HVXC:
            self = .hxvc
        @unknown default:
            self = .unknown
        }
    }
}

// MARK: -
public enum SamplingFrequency: UInt8 {
    case hz96000 = 0
    case hz88200 = 1
    case hz64000 = 2
    case hz48000 = 3
    case hz44100 = 4
    case hz32000 = 5
    case hz24000 = 6
    case hz22050 = 7
    case hz16000 = 8
    case hz12000 = 9
    case hz11025 = 10
    case hz8000 = 11
    case hz7350 = 12

    public var sampleRate: Float64 {
        switch self {
        case .hz96000:
            return 96000
        case .hz88200:
            return 88200
        case .hz64000:
            return 64000
        case .hz48000:
            return 48000
        case .hz44100:
            return 44100
        case .hz32000:
            return 32000
        case .hz24000:
            return 24000
        case .hz22050:
            return 22050
        case .hz16000:
            return 16000
        case .hz12000:
            return 12000
        case .hz11025:
            return 11025
        case .hz8000:
            return 8000
        case .hz7350:
            return 7350
        }
    }

    public init(sampleRate: Float64) {
        switch Int(sampleRate) {
        case 96000:
            self = .hz96000
        case 88200:
            self = .hz88200
        case 64000:
            self = .hz64000
        case 48000:
            self = .hz48000
        case 44100:
            self = .hz44100
        case 32000:
            self = .hz32000
        case 24000:
            self = .hz24000
        case 22050:
            self = .hz22050
        case 16000:
            self = .hz16000
        case 12000:
            self = .hz12000
        case 11025:
            self = .hz11025
        case 8000:
            self = .hz8000
        case 7350:
            self = .hz7350
        default:
            self = .hz44100
        }
    }
}

// MARK: -
enum ChannelConfiguration: UInt8 {
    case definedInAOTSpecificConfig = 0
    case frontCenter = 1
    case frontLeftAndFrontRight = 2
    case frontCenterAndFrontLeftAndFrontRight = 3
    case frontCenterAndFrontLeftAndFrontRightAndBackCenter = 4
    case frontCenterAndFrontLeftAndFrontRightAndBackLeftAndBackRight = 5
    case frontCenterAndFrontLeftAndFrontRightAndBackLeftAndBackRightLFE = 6
    case frontCenterAndFrontLeftAndFrontRightAndSideLeftAndSideRightAndBackLeftAndBackRightLFE = 7
}
