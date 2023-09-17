import AVFAudio
import Foundation

/// The AudioCodecSettings class  specifying audio compression settings.
public struct AudioCodecSettings: Codable {
    /// The default value.
    public static let `default` = AudioCodecSettings()

    /// Maximum number of channels supported by the system
    public static let maximumNumberOfChannels: UInt32 = 2
    /// Maximum sampleRate supported by the system
    public static let mamimumSampleRate: Float64 = 48000

    /// The type of the AudioCodec supports format.
    enum Format: Codable {
        /// The AAC format.
        case aac
        /// The PCM format.
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

        var bufferCounts: Int {
            switch self {
            case .aac:
                return 6
            case .pcm:
                return 1
            }
        }

        func makeAudioBuffer(_ format: AVAudioFormat) -> AVAudioBuffer? {
            switch self {
            case .aac:
                return AVAudioCompressedBuffer(format: format, packetCapacity: 1, maximumPacketSize: 1024 * Int(format.channelCount))
            case .pcm:
                return AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)
            }
        }

        func makeAudioFormat(_ inSourceFormat: AudioStreamBasicDescription?) -> AVAudioFormat? {
            guard let inSourceFormat else {
                return nil
            }
            switch self {
            case .aac:
                var streamDescription = AudioStreamBasicDescription(
                    mSampleRate: inSourceFormat.mSampleRate,
                    mFormatID: formatID,
                    mFormatFlags: formatFlags,
                    mBytesPerPacket: bytesPerPacket,
                    mFramesPerPacket: framesPerPacket,
                    mBytesPerFrame: bytesPerFrame,
                    mChannelsPerFrame: min(inSourceFormat.mChannelsPerFrame, AudioCodecSettings.maximumNumberOfChannels),
                    mBitsPerChannel: bitsPerChannel,
                    mReserved: 0
                )
                return AVAudioFormat(streamDescription: &streamDescription)
            case .pcm:
                return AVAudioFormat(
                    commonFormat: .pcmFormatFloat32,
                    sampleRate: inSourceFormat.mSampleRate,
                    channels: min(inSourceFormat.mChannelsPerFrame, AudioCodecSettings.maximumNumberOfChannels),
                    interleaved: true
                )
            }
        }
    }

    /// Specifies the bitRate of audio output.
    public var bitRate: Int
    /// Specifies the sampleRate of audio output.
    public var sampleRate: Float64
    /// Specifies the channels of audio output.
    public var channels: Int
    /// Map of the output to input channels.
    public var channelMap: [Int: Int]
    /// Specifies the output format.
    var format: AudioCodecSettings.Format = .aac

    /// Create an new AudioCodecSettings instance.
    public init(
        bitRate: Int = 64 * 1000,
        sampleRate: Float64 = 0,
        channels: Int = 0,
        channelMap: [Int: Int] = [0: 0, 1: 1]
    ) {
        self.bitRate = bitRate
        self.sampleRate = sampleRate
        self.channels = channels
        self.channelMap = channelMap
    }

    func invalidateConverter(_ oldValue: AudioCodecSettings) -> Bool {
        return !(
            sampleRate == oldValue.sampleRate &&
                channels == oldValue.channels &&
                channelMap == oldValue.channelMap
        )
    }

    func apply(_ converter: AVAudioConverter?, oldValue: AudioCodecSettings?) {
        guard let converter else {
            return
        }
        if bitRate != oldValue?.bitRate {
            let minAvailableBitRate = converter.applicableEncodeBitRates?.min(by: { a, b in
                return a.intValue < b.intValue
            })?.intValue ?? bitRate
            let maxAvailableBitRate = converter.applicableEncodeBitRates?.max(by: { a, b in
                return a.intValue < b.intValue
            })?.intValue ?? bitRate
            converter.bitRate = min(maxAvailableBitRate, max(minAvailableBitRate, bitRate))
        }
    }

    func makeOutputChannels(_ inChannels: Int) -> Int {
        return min(channels == 0 ? inChannels : channels, Int(Self.maximumNumberOfChannels))
    }

    func makeChannelMap(_ inChannels: Int) -> [NSNumber] {
        let outChannels = makeOutputChannels(inChannels)
        var result = Array(repeating: -1, count: outChannels)
        for inputIndex in 0..<min(inChannels, outChannels) {
            result[inputIndex] = inputIndex
        }
        for currentIndex in 0..<outChannels {
            if let inputIndex = channelMap[currentIndex], inputIndex < inChannels {
                result[currentIndex] = inputIndex
            }
        }
        return result.map { NSNumber(value: $0) }
    }

    func makeOutputFormat(_ inputFormat: AVAudioFormat?) -> AVAudioFormat? {
        guard let inputFormat else {
            return nil
        }
        let numberOfChannels = makeOutputChannels(Int(inputFormat.channelCount))
        guard let channelLayout = AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_DiscreteInOrder | UInt32(numberOfChannels)) else {
            return nil
        }
        return .init(
            commonFormat: inputFormat.commonFormat,
            sampleRate: min(sampleRate == 0 ? inputFormat.sampleRate : sampleRate, Self.mamimumSampleRate),
            interleaved: inputFormat.isInterleaved,
            channelLayout: channelLayout
        )
    }
}
