import AVFAudio
import Foundation

/// Constraints on the audio codec compression settings.
public struct AudioCodecSettings: Codable, Sendable {
    /// The default value.
    public static let `default` = AudioCodecSettings()
    /// The default bitRate. The value is 64,000 bps.
    public static let defaultBitRate = 64 * 1000
    /// Maximum number of channels supported by the system
    public static let maximumNumberOfChannels: UInt32 = 8

    /// The type of the AudioCodec supports format.
    public enum Format: Codable, Sendable {
        /// The AAC format.
        case aac
        /// The OPUS format.
        case opus
        /// The PCM format.
        case pcm

        var formatID: AudioFormatID {
            switch self {
            case .aac:
                return kAudioFormatMPEG4AAC
            case .opus:
                return kAudioFormatOpus
            case .pcm:
                return kAudioFormatLinearPCM
            }
        }

        var formatFlags: UInt32 {
            switch self {
            case .aac:
                return UInt32(MPEG4ObjectID.AAC_LC.rawValue)
            case .opus:
                return 0
            case .pcm:
                return kAudioFormatFlagIsNonInterleaved
                    | kAudioFormatFlagIsPacked
                    | kAudioFormatFlagIsFloat
            }
        }

        var packetSize: UInt32 {
            switch self {
            case .aac:
                return 1
            case .opus:
                return 1
            case .pcm:
                return 1024
            }
        }

        var bitsPerChannel: UInt32 {
            switch self {
            case .aac:
                return 0
            case .opus:
                return 0
            case .pcm:
                return 32
            }
        }

        var bytesPerPacket: UInt32 {
            switch self {
            case .aac:
                return 0
            case .opus:
                return 0
            case .pcm:
                return (bitsPerChannel / 8)
            }
        }

        var bytesPerFrame: UInt32 {
            switch self {
            case .aac:
                return 0
            case .opus:
                return 0
            case .pcm:
                return (bitsPerChannel / 8)
            }
        }

        var inputBufferCounts: Int {
            switch self {
            case .aac:
                return 6
            case .opus:
                return 6
            case .pcm:
                return 1
            }
        }

        var outputBufferCounts: Int {
            switch self {
            case .aac:
                return 1
            case .opus:
                return 1
            case .pcm:
                return 24
            }
        }

        var supportedSampleRate: [Float64]? {
            switch self {
            case .opus:
                return [8000.0, 12000.0, 16000.0, 24000.0, 48000.0]
            default:
                return nil
            }
        }

        func makeSampleRate(_ input: Float64, output: Float64) -> Float64 {
            let sampleRate = output == 0 ? input : output
            guard let supportedSampleRate else {
                return sampleRate
            }
            return supportedSampleRate.sorted { pow($0 - sampleRate, 2) < pow($1 - sampleRate, 2) }.first ?? sampleRate
        }

        func makeFramesPerPacket(_ sampleRate: Double) -> UInt32 {
            switch self {
            case .aac:
                return 1024
            case .opus:
                // https://www.rfc-editor.org/rfc/rfc6716#section-2.1.4
                let frameDurationSec = 0.02
                return UInt32(sampleRate * frameDurationSec)
            case .pcm:
                return 1
            }
        }

        func makeAudioBuffer(_ format: AVAudioFormat) -> AVAudioBuffer? {
            switch self {
            case .aac:
                return AVAudioCompressedBuffer(format: format, packetCapacity: 1, maximumPacketSize: 1024 * Int(format.channelCount))
            case .opus:
                return AVAudioCompressedBuffer(format: format, packetCapacity: 1, maximumPacketSize: 1024 * Int(format.channelCount))
            case .pcm:
                return AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)
            }
        }

        func makeOutputAudioFormat(_ format: AVAudioFormat, sampleRate: Float64) -> AVAudioFormat? {
            let mSampleRate = makeSampleRate(format.sampleRate, output: sampleRate)
            let config = AudioSpecificConfig.ChannelConfiguration(channelCount: format.channelCount)
            var streamDescription = AudioStreamBasicDescription(
                mSampleRate: mSampleRate,
                mFormatID: formatID,
                mFormatFlags: formatFlags,
                mBytesPerPacket: bytesPerPacket,
                mFramesPerPacket: makeFramesPerPacket(mSampleRate),
                mBytesPerFrame: bytesPerFrame,
                mChannelsPerFrame: min(
                    config?.channelCount ?? format.channelCount,
                    AudioCodecSettings.maximumNumberOfChannels
                ),
                mBitsPerChannel: bitsPerChannel,
                mReserved: 0
            )
            return AVAudioFormat(
                streamDescription: &streamDescription,
                channelLayout: config?.audioChannelLayout
            )
        }
    }

    /// Specifies the bitRate of audio output.
    public var bitRate: Int

    /// Specifies the mixes the channels or not.
    public var downmix: Bool

    /// Specifies the map of the output to input channels.
    public var channelMap: [Int]?

    /// Specifies the sampleRate of audio output. A value of 0 will be the same as the main track source.
    public let sampleRate: Float64

    /// Specifies the output format.
    public var format: AudioCodecSettings.Format = .aac

    /// Creates a new instance.
    public init(
        bitRate: Int = AudioCodecSettings.defaultBitRate,
        downmix: Bool = true,
        channelMap: [Int]? = nil,
        sampleRate: Float64 = 0,
        format: AudioCodecSettings.Format = .aac
    ) {
        self.bitRate = bitRate
        self.downmix = downmix
        self.channelMap = channelMap
        self.sampleRate = sampleRate
        self.format = format
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

        if downmix != oldValue?.downmix {
            converter.downmix = downmix
        }

        if channelMap != oldValue?.channelMap, let newChannelMap = validatedChannelMap(converter) {
            converter.channelMap = newChannelMap
        }
    }

    private func validatedChannelMap(_ converter: AVAudioConverter) -> [NSNumber]? {
        guard let channelMap, channelMap.count == converter.outputFormat.channelCount else {
            return nil
        }
        for inputChannel in channelMap where converter.inputFormat.channelCount <= inputChannel {
            return nil
        }
        return channelMap.map { NSNumber(value: $0) }
    }
}
