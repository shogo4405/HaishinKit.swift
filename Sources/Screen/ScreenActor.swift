import Foundation

/// A singleton actor whose executor screen object rendering.
@globalActor
public actor ScreenActor {
    /// The shared actor instance.
    public static let shared = ScreenActor()

    private init() {
    }
}
