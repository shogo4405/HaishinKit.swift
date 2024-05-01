import AVFAudio
import Foundation

/// Constraints on the audio codec  compression settings.
public struct AudioCodecSettings: Codable {
    /// The default value.
    public static let `default` = AudioCodecSettings()
    /// Maximum number of channels supported by the system
    static let maximumNumberOfChannels: UInt32 = 8

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
                return kAudioFormatFlagIsNonInterleaved
                    | kAudioFormatFlagIsPacked
                    | kAudioFormatFlagIsFloat
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
            let config = AudioSpecificConfig.ChannelConfiguration(channelCount: format.channelCount)
            var streamDescription = AudioStreamBasicDescription(
                mSampleRate: format.sampleRate,
                mFormatID: formatID,
                mFormatFlags: formatFlags,
                mBytesPerPacket: bytesPerPacket,
                mFramesPerPacket: framesPerPacket,
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
    public var bitRate: Int = 64 * 1000

    /// Specifies the mixes the channels or not. Currently, it supports input sources with 4, 5, 6, and 8 channels.
    public var downmix = true

    /// Specifies the map of the output to input channels.
    /// ## Example code:
    /// ```
    /// // If you want to use the 3rd and 4th channels from a 4-channel input source for a 2-channel output, you would specify it like this.
    /// channelMap = [2, 3]
    /// ```
    public var channelMap: [Int]?

    /// Specifies the output format.
    var format: AudioCodecSettings.Format = .aac

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
