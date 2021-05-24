import Foundation

enum ElementaryStreamType: UInt8 {
    case mpeg1Video = 0x01
    case mpeg2Video = 0x02
    case mpeg1Audio = 0x03
    case mpeg2Audio = 0x04
    case mpeg2TabledData = 0x05
    case mpeg2PacketizedData = 0x06

    case adtsaac = 0x0F
    case h263 = 0x10

    case h264 = 0x1B
    case h265 = 0x24
}
