import Foundation
import AVFoundation

// @see http://wiki.multimedia.cx/index.php?title=MPEG-4_Audio#Audio_Specific_Config

public struct AudioSpecificConfig: CustomStringConvertible {
    public var type:AudioObjectType
    public var frequency:SamplingFrequency
    public var channel:ChannelConfiguration

    public var description:String {
        return "AudioSpecificConfig{type:\(type),frequency:\(frequency),channel:\(channel)}"
    }

    public var bytes:[UInt8] {
        var bytes:[UInt8] = [UInt8](count: 2, repeatedValue: 0)
        bytes[0] = type.rawValue << 3 | (frequency.rawValue >> 1 & 0x3)
        bytes[1] = (frequency.rawValue & 0x1) << 7 | (channel.rawValue & 0xF) << 3
        return bytes
    }

    public init(type:AudioObjectType, frequency:SamplingFrequency, channel:ChannelConfiguration) {
        self.type = type
        self.frequency = frequency
        self.channel = channel
    }

    public init(formatDescription: CMFormatDescriptionRef) {
        let asbd:AudioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription).memory
        type = AudioObjectType(formatID: asbd.mFormatID)
        frequency = SamplingFrequency(sampleRate: asbd.mSampleRate)
        channel = ChannelConfiguration(rawValue: UInt8(asbd.mChannelsPerFrame))!
    }
}

public enum AudioObjectType:UInt8 {
    case Null = 0
    case AACMain = 1
    case AACLC = 2
    case AACSSR = 3
    case AACLTP = 4
    case SBR = 5
    case AACScalable = 6

    public init (formatID: AudioFormatID) {
        switch formatID {
        case kAudioFormatMPEG4AAC:
            self = .AACMain
        default:
            self = .Null
        }
    }
}

public enum SamplingFrequency:UInt8 {
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
    case hz8000  = 11
    case hz7350  = 12

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

public enum ChannelConfiguration:UInt8 {
    case definedInAOTSpecificConfig = 0
    case frontCenter = 1
    case frontLeftAndFrontRight = 2
    case frontCenterAndFrontLeftAndFrontRight = 3
    case frontCenterAndFrontLeftAndFrontRightAndBackCenter = 4
    case frontCenterAndFrontLeftAndFrontRightAndBackLeftAndBackRight = 5
    case frontCenterAndFrontLeftAndFrontRightAndBackLeftAndBackRightLFE = 6
    case frontCenterAndFrontLeftAndFrontRightAndSideLeftAndSideRightAndBackLeftAndBackRightLFE = 7
}
