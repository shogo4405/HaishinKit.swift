import Foundation

/// The AudioCodecSettings class  specifying audio compression settings.
public struct AudioCodecSettings: Codable {
    /// The defualt value.
    public static let `default` = AudioCodecSettings()

    /// Specifies the bitRate of audio output.
    public var bitRate: UInt32 = 32 * 1000

    /// Create an new AudioCodecSettings instance.
    public init(bitRate: UInt32 = 32 * 1000) {
        self.bitRate = bitRate
    }
}
