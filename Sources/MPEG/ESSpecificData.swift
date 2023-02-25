import CoreMedia
import Foundation

enum ESType: UInt8 {
    case mpeg1Video = 0x01
    case mpeg2Video = 0x02
    case mpeg1Audio = 0x03
    case mpeg2Audio = 0x04
    case mpeg2TabledData = 0x05
    case mpeg2PacketizedData = 0x06

    case adtsAac = 0x0F
    case h263 = 0x10

    case h264 = 0x1B
    case h265 = 0x24
}

struct ESSpecificData {
    static let fixedHeaderSize: Int = 5

    var streamType: UInt8 = 0
    var elementaryPID: UInt16 = 0
    var esInfoLength: UInt16 = 0
    var esDescriptors = Data()

    init() {
    }

    init?(_ data: Data) {
        self.data = data
    }
}

extension ESSpecificData: DataConvertible {
    // MARK: DataConvertible
    var data: Data {
        get {
            ByteArray()
                .writeUInt8(streamType)
                .writeUInt16(elementaryPID | 0xe000)
                .writeUInt16(esInfoLength | 0xf000)
                .writeBytes(esDescriptors)
                .data
        }
        set {
            let buffer = ByteArray(data: newValue)
            do {
                streamType = try buffer.readUInt8()
                elementaryPID = try buffer.readUInt16() & 0x0fff
                esInfoLength = try buffer.readUInt16() & 0x01ff
                esDescriptors = try buffer.readBytes(Int(esInfoLength))
            } catch {
                logger.error("\(buffer)")
            }
        }
    }
}

extension ESSpecificData: CustomDebugStringConvertible {
    // MARK: CustomDebugStringConvertible
    var debugDescription: String {
        Mirror(reflecting: self).debugDescription
    }
}
