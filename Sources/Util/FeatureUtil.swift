import Foundation

/// The util object to get feature flag info.
public enum FeatureUtil {
    /// A structure that defines the name of a feature.
    public struct Name: RawRepresentable, ExpressibleByStringLiteral {
        // swiftlint:disable:next nesting
        public typealias RawValue = String
        // swiftlint:disable:next nesting
        public typealias StringLiteralType = String

        /// This is a feature to mix multiple audio tracks. For example, it is possible to mix .appAudio and .micAudio from ReplayKit.
        public static let multiTrackMixing: Name = "multiTrackMixing"

        /// The raw type value.
        public let rawValue: String

        /// Create a feature name by rawValue.
        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// Create a feature name by stringLiteral.
        public init(stringLiteral value: String) {
            self.rawValue = value
        }
    }

    private static var flags: [String: Bool] = [:]

    /// Whether or not a flag is enabled.
    public static func isEnabled(feature: Name) -> Bool {
        return flags[feature.rawValue] ?? false
    }

    /// Setter for a feature flag.
    public static func setEnabled(
        feature: Name,
        isEnabled: Bool
    ) {
        flags[feature.rawValue] = isEnabled
    }
}
