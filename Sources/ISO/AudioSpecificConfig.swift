import AVFoundation

/**
 The Audio Specific Config is the global header for MPEG-4 Audio
 - seealso: http://wiki.multimedia.cx/index.php?title=MPEG-4_Audio#Audio_Specific_Config
 - seealso: http://wiki.multimedia.cx/?title=Understanding_AAC
 */
struct AudioSpecificConfig: Equatable {
    static let adtsHeaderSize: Int = 7

    enum AudioObjectType: UInt8 {
        case unknown = 0
        case aacMain = 1
        case aacLc = 2
        case aacSsr = 3
        case aacLtp = 4
        case aacSbr = 5
        case aacScalable = 6
        case twinqVQ = 7
        case celp = 8
        case hxvc = 9

        init?(objectID: MPEG4ObjectID?) {
            switch objectID {
            case .aac_Main?:
                self = .aacMain
            case .AAC_LC?:
                self = .aacLc
            case .AAC_SSR?:
                self = .aacSsr
            case .AAC_LTP?:
                self = .aacLtp
            case .AAC_SBR?:
                self = .aacSbr
            case .aac_Scalable?:
                self = .aacScalable
            case .twinVQ?:
                self = .twinqVQ
            case .CELP?:
                self = .celp
            case .HVXC?:
                self = .hxvc
            case .none:
                return nil
            @unknown default:
                return nil
            }
        }
    }

    enum SamplingFrequency: UInt8 {
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

        var sampleRate: Float64 {
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

        init?(sampleRate: Float64) {
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
                return nil
            }
        }
    }

    enum ChannelConfiguration: UInt8 {
        case definedInAOTSpecificConfig = 0
        case frontCenter = 1
        case frontLeftAndFrontRight = 2
        case frontCenterAndFrontLeftAndFrontRight = 3
        case frontCenterAndFrontLeftAndFrontRightAndBackCenter = 4
        case frontCenterAndFrontLeftAndFrontRightAndBackLeftAndBackRight = 5
        case frontCenterAndFrontLeftAndFrontRightAndBackLeftAndBackRightLFE = 6
        case frontCenterAndFrontLeftAndFrontRightAndSideLeftAndSideRightAndBackLeftAndBackRightLFE = 7

        var channelCount: UInt32 {
            switch self {
            case .definedInAOTSpecificConfig:
                return 0
            case .frontCenter:
                return 1
            case .frontLeftAndFrontRight:
                return 2
            case .frontCenterAndFrontLeftAndFrontRight:
                return 3
            case .frontCenterAndFrontLeftAndFrontRightAndBackCenter:
                return 4
            case .frontCenterAndFrontLeftAndFrontRightAndBackLeftAndBackRight:
                return 5
            case .frontCenterAndFrontLeftAndFrontRightAndBackLeftAndBackRightLFE:
                return 6
            case .frontCenterAndFrontLeftAndFrontRightAndSideLeftAndSideRightAndBackLeftAndBackRightLFE:
                return 8
            }
        }

        var audioChannelLayoutTag: AudioChannelLayoutTag? {
            switch self {
            case .definedInAOTSpecificConfig:
                return nil
            case .frontCenter:
                return nil
            case .frontLeftAndFrontRight:
                return nil
            case .frontCenterAndFrontLeftAndFrontRight:
                return kAudioChannelLayoutTag_MPEG_3_0_B
            case .frontCenterAndFrontLeftAndFrontRightAndBackCenter:
                return kAudioChannelLayoutTag_MPEG_4_0_B
            case .frontCenterAndFrontLeftAndFrontRightAndBackLeftAndBackRight:
                return kAudioChannelLayoutTag_MPEG_5_0_D
            case .frontCenterAndFrontLeftAndFrontRightAndBackLeftAndBackRightLFE:
                return kAudioChannelLayoutTag_MPEG_5_1_D
            case .frontCenterAndFrontLeftAndFrontRightAndSideLeftAndSideRightAndBackLeftAndBackRightLFE:
                return kAudioChannelLayoutTag_MPEG_7_1_B
            }
        }

        var audioChannelLayout: AVAudioChannelLayout? {
            guard let audioChannelLayoutTag else {
                return nil
            }
            return AVAudioChannelLayout(layoutTag: audioChannelLayoutTag)
        }

        init?(channelCount: UInt32) {
            switch channelCount {
            case 0:
                self = .definedInAOTSpecificConfig
            case 1:
                self = .frontCenter
            case 2:
                self = .frontLeftAndFrontRight
            case 3:
                self = .frontCenterAndFrontLeftAndFrontRight
            case 4:
                self = .frontCenterAndFrontLeftAndFrontRightAndBackCenter
            case 5:
                self = .frontCenterAndFrontLeftAndFrontRightAndBackLeftAndBackRight
            case 6:
                self = .frontCenterAndFrontLeftAndFrontRightAndBackLeftAndBackRightLFE
            case 8:
                self = .frontCenterAndFrontLeftAndFrontRightAndSideLeftAndSideRightAndBackLeftAndBackRightLFE
            default:
                return nil
            }
        }
    }

    let type: AudioObjectType
    let frequency: SamplingFrequency
    let channelConfig: ChannelConfiguration
    let frameLengthFlag = false

    var bytes: [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 2)
        bytes[0] = type.rawValue << 3 | (frequency.rawValue >> 1)
        bytes[1] = (frequency.rawValue & 0x1) << 7 | (channelConfig.rawValue & 0xF) << 3
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
        self.channelConfig = channel
    }

    init(type: AudioObjectType, frequency: SamplingFrequency, channel: ChannelConfiguration) {
        self.type = type
        self.frequency = frequency
        self.channelConfig = channel
    }

    init?(formatDescription: CMFormatDescription?) {
        guard
            let streamDescription = formatDescription?.audioStreamBasicDescription,
            let type = AudioObjectType(objectID: MPEG4ObjectID(rawValue: Int(streamDescription.mFormatFlags))),
            let frequency = SamplingFrequency(sampleRate: streamDescription.mSampleRate),
            let channelConfig = ChannelConfiguration(channelCount: streamDescription.mChannelsPerFrame) else {
            return nil
        }
        self.type = type
        self.frequency = frequency
        self.channelConfig = channelConfig
    }

    func encode(to data: inout Data, length: Int) {
        let fullSize: Int = Self.adtsHeaderSize + length
        data[0] = 0xFF
        data[1] = 0xF9
        data[2] = (type.rawValue - 1) << 6 | (frequency.rawValue << 2) | (channelConfig.rawValue >> 2)
        data[3] = (channelConfig.rawValue & 3) << 6 | UInt8(fullSize >> 11)
        data[4] = UInt8((fullSize & 0x7FF) >> 3)
        data[5] = ((UInt8(fullSize & 7)) << 5) + 0x1F
        data[6] = 0xFC
    }

    func makeAudioFormat() -> AVAudioFormat? {
        var audioStreamBasicDescription = makeAudioStreamBasicDescription()
        if let audioChannelLayoutTag = channelConfig.audioChannelLayoutTag {
            return AVAudioFormat(
                streamDescription: &audioStreamBasicDescription,
                channelLayout: AVAudioChannelLayout(layoutTag: audioChannelLayoutTag)
            )
        }
        return AVAudioFormat(streamDescription: &audioStreamBasicDescription)
    }

    private func makeAudioStreamBasicDescription() -> AudioStreamBasicDescription {
        AudioStreamBasicDescription(
            mSampleRate: frequency.sampleRate,
            mFormatID: kAudioFormatMPEG4AAC,
            mFormatFlags: UInt32(type.rawValue),
            mBytesPerPacket: 0,
            mFramesPerPacket: frameLengthFlag ? 960 : 1024,
            mBytesPerFrame: 0,
            mChannelsPerFrame: channelConfig.channelCount,
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
