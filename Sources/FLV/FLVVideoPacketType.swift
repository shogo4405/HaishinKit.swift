import Foundation

enum FLVVideoPacketType: UInt8 {
    case sequenceStart = 0
    case codedFrames = 1
    case sequenceEnd = 2
    case codedFramesX = 3
    case metadata = 4
    case mpeg2TSSequenceStart = 5
}
