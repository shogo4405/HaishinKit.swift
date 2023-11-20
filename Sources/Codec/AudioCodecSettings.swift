import AVFAudio
import Foundation

/// The AudioCodecSettings class  specifying audio compression settings.
public struct AudioCodecSettings: Codable {
    /// The default value.
    public static let `default` = AudioCodecSettings()
    /// Maximum number of channels supported by the system
    public static let maximumNumberOfChannels: UInt32 = 2
    /// Maximum sampleRate supported by the system
    public static let mamimumSampleRate: Float64 = 48000.0

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
                return kAudioFormatFlagIsNonInterleaved | kAudioFormatFlagIsPacked | kAudioFormatFlagIsFloat | kAudioFormatFlagIsNonInterleaved
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

        var inputBufferCounts: Int {
            switch self {
            case .aac:
                return 6
            case .pcm:
                return 1
            }
        }

        var outputBufferCounts: Int {
            switch self {
            case .aac:
                return 1
            case .pcm:
                return 24
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

        func makeAudioFormat(_ format: AVAudioFormat) -> AVAudioFormat? {
            var streamDescription = AudioStreamBasicDescription(
                mSampleRate: format.sampleRate,
                mFormatID: formatID,
                mFormatFlags: formatFlags,
                mBytesPerPacket: bytesPerPacket,
                mFramesPerPacket: framesPerPacket,
                mBytesPerFrame: bytesPerFrame,
                mChannelsPerFrame: min(format.channelCount, AudioCodecSettings.maximumNumberOfChannels),
                mBitsPerChannel: bitsPerChannel,
                mReserved: 0
            )
            return AVAudioFormat(streamDescription: &streamDescription)
        }
    }

    /// Specifies the bitRate of audio output.
    public var bitRate: Int
    /// Specifies the sampleRate of audio output.
    public var sampleRate: Float64
    /// Specifies the channels of audio output.
    public var channels: UInt32
    /// Specifies the mixes the channels or not. Currently, it supports input sources with 4, 5, 6, and 8 channels.
    public var downmix: Bool
    /// Specifies the map of the output to input channels.
    /// ## Example code:
    /// ```
    /// // If you want to use the 3rd and 4th channels from a 4-channel input source for a 2-channel output, you would specify it like this.
    /// channelMap = [2, 3]
    /// ```
    public var channelMap: [Int]?
    /// Specifies the output format.
    var format: AudioCodecSettings.Format = .aac

    /// Create an new AudioCodecSettings instance. A value of 0 will use the same value as the input source.
    public init(
        bitRate: Int = 64 * 1000,
        sampleRate: Float64 = 0,
        channels: UInt32 = 0,
        downmix: Bool = false,
        channelMap: [Int]? = nil
    ) {
        self.bitRate = bitRate
        self.sampleRate = sampleRate
        self.channels = channels
        self.downmix = downmix
        self.channelMap = channelMap
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

    func makeAudioResamplerSettings() -> IOAudioResamplerSettings {
        return .init(
            sampleRate: sampleRate,
            channels: channels,
            downmix: downmix,
            channelMap: channelMap?.map { NSNumber(value: $0) }
        )
    }
}
