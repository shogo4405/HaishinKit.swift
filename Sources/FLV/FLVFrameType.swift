/// The type of flv supports video frame types.
enum FLVFrameType: UInt8 {
    /// The keyframe.
    case key = 1
    /// The inter frame.
    case inter = 2
    /// The disposable inter frame.
    case disposable = 3
    /// The generated keydrame.
    case generated = 4
    /// The video info or command frame.
    case command = 5
}
