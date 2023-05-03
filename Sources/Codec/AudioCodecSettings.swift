import AVFAudio
import Foundation

/// The AudioCodecSettings class  specifying audio compression settings.
public struct AudioCodecSettings: Codable {
    /// The defualt value.
    public static let `default` = AudioCodecSettings()

    /// The type of the AudioCodec supports format.
    public enum Format: Codable {
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

        func makeAudioBuffer(_ format: AVAudioFormat) -> AVAudioBuffer? {
            switch self {
            case .aac:
                return AVAudioCompressedBuffer(format: format, packetCapacity: 1, maximumPacketSize: 1024)
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
                    mChannelsPerFrame: inSourceFormat.mChannelsPerFrame,
                    mBitsPerChannel: bitsPerChannel,
                    mReserved: 0
                )
                return AVAudioFormat(streamDescription: &streamDescription)
            case .pcm:
                return AVAudioFormat(
                    commonFormat: .pcmFormatFloat32,
                    sampleRate: inSourceFormat.mSampleRate,
                    channels: inSourceFormat.mChannelsPerFrame,
                    interleaved: true
                )
            }
        }
    }

    /// Specifies the bitRate of audio output.
    public var bitRate: Int

    /// Specifies the output format.
    public var format: AudioCodecSettings.Format

    /// Create an new AudioCodecSettings instance.
    public init(
        bitRate: Int = 64 * 1000,
        format: AudioCodecSettings.Format = .aac
    ) {
        self.bitRate = bitRate
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
    }
}
