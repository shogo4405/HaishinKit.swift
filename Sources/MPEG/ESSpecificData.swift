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


struct ElementaryStreamSpecificData {
    static let fixedHeaderSize: Int = 5

    var streamType: UInt8 = 0
    var elementaryPID: UInt16 = 0
    var ESInfoLength: UInt16 = 0
    var ESDescriptors = Data()

    init() {
    }

    init?(_ data: Data) {
        self.data = data
    }
}

extension ElementaryStreamSpecificData: DataConvertible {
    // MARK: DataConvertible
    var data: Data {
        get {
            ByteArray()
                .writeUInt8(streamType)
                .writeUInt16(elementaryPID | 0xe000)
                .writeUInt16(ESInfoLength | 0xf000)
                .writeBytes(ESDescriptors)
                .data
        }
        set {
            let buffer = ByteArray(data: newValue)
            do {
                streamType = try buffer.readUInt8()
                elementaryPID = try buffer.readUInt16() & 0x0fff
                ESInfoLength = try buffer.readUInt16() & 0x01ff
                ESDescriptors = try buffer.readBytes(Int(ESInfoLength))
            } catch {
                logger.error("\(buffer)")
            }
        }
    }
}

extension ElementaryStreamSpecificData: CustomDebugStringConvertible {
    // MARK: CustomDebugStringConvertible
    var debugDescription: String {
        Mirror(reflecting: self).debugDescription
    }
}
