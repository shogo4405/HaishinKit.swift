enum RTMPVideoFourCC: UInt32 {
    case av1 = 0x61763031 // { 'a', 'v', '0', '1' }
    case vp9 = 0x76703039 // { 'v', 'p', '0', '9' }
    case hevc = 0x68766331 // { 'h', 'v', 'c', '1' }

    var isSupported: Bool {
        switch self {
        case .av1:
            return false
        case .vp9:
            return false
        case .hevc:
            return true
        }
    }
}

enum RTMPVideoPacketType: UInt8 {
    case sequenceStart = 0
    case codedFrames = 1
    case sequenceEnd = 2
    case codedFramesX = 3
    case metadata = 4
    case mpeg2TSSequenceStart = 5
}
