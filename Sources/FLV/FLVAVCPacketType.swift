/// The type of flv supports avc packet types.
enum FLVAVCPacketType: UInt8 {
    /// The sequence data.
    case seq = 0
    /// The NAL unit data.
    case nal = 1
    /// The end of stream data.
    case eos = 2
}
