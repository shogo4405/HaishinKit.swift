import Foundation

/**
 - seealso: https://en.wikipedia.org/wiki/Program-specific_information
 */
protocol PSIPointer {
    var pointerField:UInt8 { get set }
    var pointerFillerBytes:[UInt8] { get set }
}

// MARK: -
protocol PSITableHeader {
    var tableID:UInt8 { get set }
    var sectionSyntaxIndicator:Bool { get set }
    var privateBit:Bool { get set }
    var sectionLength:UInt16 { get set }
}

// MARK: -
protocol PSITableSyntax {
    var tableIDExtension:UInt16 { get set }
    var versionNumber:UInt8 { get set }
    var currentNextIndicator:Bool { get set }
    var sectionNumber:UInt8 { get set }
    var lastSectionNumber:UInt8 { get set }
    var data:[UInt8] { get set }
    var crc32:UInt32 { get set }
}

// MARK: -
class ProgramSpecific: PSIPointer, PSITableHeader, PSITableSyntax {
    static let reservedBits:UInt8 = 0x03
    static let defaultTableIDExtension:UInt16 = 1

    // MARK: PSIPointer
    var pointerField:UInt8 = 0
    var pointerFillerBytes:[UInt8] = []

    // MARK: PSITableHeader
    var tableID:UInt8 = 0
    var sectionSyntaxIndicator:Bool = false
    var privateBit:Bool = false
    var sectionLength:UInt16 = 0

    // MARK: PSITableSyntax
    var tableIDExtension:UInt16 = ProgramSpecific.defaultTableIDExtension
    var versionNumber:UInt8 = 0
    var currentNextIndicator:Bool = true
    var sectionNumber:UInt8 = 0
    var lastSectionNumber:UInt8 = 0
    var data:[UInt8] {
        get {
            return []
        }
        set {
            
        }
    }
    var crc32:UInt32 = 0

    init() {
    }

    init?(bytes:[UInt8]) {
        self.bytes = bytes
    }

    func arrayOfPackets(_ PID:UInt16) -> [TSPacket] {
        var packets:[TSPacket] = []
        var packet:TSPacket = TSPacket()
        packet.payloadUnitStartIndicator = true
        packet.PID = PID
        let _ = packet.fill(bytes, useAdaptationField: false)
        packets.append(packet)
        return packets
    }
}

extension ProgramSpecific: CustomStringConvertible {
    // MARK: CustomStringConvertible
    var description:String {
        return Mirror(reflecting: self).description
    }
}

extension ProgramSpecific: BytesConvertible {
    // MARK: BytesConvertible
    var bytes:[UInt8] {
        get {
            let data:[UInt8] = self.data
            sectionLength = UInt16(data.count) + 9
            sectionSyntaxIndicator = data.count != 0
            let buffer:ByteArray = ByteArray()
                .writeUInt8(tableID)
                .writeUInt16(
                    (sectionSyntaxIndicator ? 0x8000 : 0) |
                    (privateBit ? 0x4000 : 0) |
                    UInt16(ProgramSpecific.reservedBits) << 12 |
                    sectionLength
                )
                .writeUInt16(tableIDExtension)
                .writeUInt8(
                    ProgramSpecific.reservedBits << 6 |
                    versionNumber << 1 |
                    (currentNextIndicator ? 1 : 0)
                )
                .writeUInt8(sectionNumber)
                .writeUInt8(lastSectionNumber)
                .writeBytes(data)
            crc32 = CRC32.MPEG2.calculate(buffer.bytes)
            return [pointerField] + pointerFillerBytes + buffer.writeUInt32(crc32).bytes
        }
        set {
            let buffer:ByteArray = ByteArray(bytes: newValue)
            do {
                var bytes:[UInt8] = []
                pointerField = try buffer.readUInt8()
                pointerFillerBytes = try buffer.readBytes(Int(pointerField))
                tableID = try buffer.readUInt8()
                bytes = try buffer.readBytes(2)
                sectionSyntaxIndicator = bytes[0] & 0x80 == 0x80
                privateBit = bytes[0] & 0x40 == 0x40
                sectionLength = UInt16(bytes[0] & 0x03) << 8 | UInt16(bytes[1])
                tableIDExtension = try buffer.readUInt16()
                versionNumber = try buffer.readUInt8()
                currentNextIndicator = versionNumber & 0x01 == 0x01
                versionNumber = (versionNumber & 0b00111110) >> 1
                sectionNumber = try buffer.readUInt8()
                lastSectionNumber = try buffer.readUInt8()
                data = try buffer.readBytes(Int(sectionLength - 9))
                crc32 = try buffer.readUInt32()
            } catch {
                logger.error("\(buffer)")
            }
        }
    }
}

// MARK: -
final class ProgramAssociationSpecific: ProgramSpecific {
    static let tableID:UInt8 = 0

    var programs:[UInt16:UInt16] = [:]

    override var data:[UInt8] {
        get {
            let buffer:ByteArray = ByteArray()
            for (number, programMapPID) in programs {
                buffer.writeUInt16(number).writeUInt16(programMapPID | 0xe000)
            }
            return buffer.bytes
        }
        set {
            let buffer:ByteArray = ByteArray(bytes: newValue)
            do {
                for _ in 0..<newValue.count / 4 {
                    programs[try buffer.readUInt16()] = try buffer.readUInt16() & 0x1fff
                }
            } catch {
                logger.error("\(buffer)")
            }
        }
    }
}

// MARK: -
final class ProgramMapSpecific: ProgramSpecific {
    static let tableID:UInt8 = 2
    static let unusedPCRID:UInt16 = 0x1fff

    var PCRPID:UInt16 = 0
    var programInfoLength:UInt16 = 0
    var elementaryStreamSpecificData:[ElementaryStreamSpecificData] = []

    override init() {
        super.init()
        tableID = ProgramMapSpecific.tableID
    }

    override init?(bytes:[UInt8]) {
        super.init()
        self.bytes = bytes
    }

    override var data:[UInt8] {
        get {
            var bytes:[UInt8] = []
            for data in elementaryStreamSpecificData {
                bytes += data.bytes
            }
            return ByteArray()
                .writeUInt16(PCRPID | 0xe000)
                .writeUInt16(programInfoLength | 0xf000)
                .writeBytes(bytes)
                .bytes
        }
        set {
            let buffer:ByteArray = ByteArray(bytes: newValue)
            do {
                PCRPID = try buffer.readUInt16() & 0x1fff
                programInfoLength = try buffer.readUInt16() & 0x03ff
                buffer.position += Int(programInfoLength)
                var position:Int = 0
                while (0 < buffer.bytesAvailable) {
                    position = buffer.position
                    guard let data:ElementaryStreamSpecificData = ElementaryStreamSpecificData(bytes: try buffer.readBytes(buffer.bytesAvailable)) else {
                        break
                    }
                    buffer.position = position + ElementaryStreamSpecificData.fixedHeaderSize + Int(data.ESInfoLength)
                    elementaryStreamSpecificData.append(data)
                }
            } catch {
                logger.error("\(buffer)")
            }
        }
    }
}

// MARK: -
enum ElementaryStreamType: UInt8 {
    case mpeg1Video          = 0x01
    case mpeg2Video          = 0x02
    case mpeg1Audio          = 0x03
    case mpeg2Audio          = 0x04
    case mpeg2TabledData     = 0x05
    case mpeg2PacketizedData = 0x06

    case adtsaac  = 0x0F
    case h263     = 0x10

    case h264     = 0x1B
    case h265     = 0x24
}

// MARK: -
struct ElementaryStreamSpecificData {
    static let fixedHeaderSize:Int = 5

    var streamType:UInt8 = 0
    var elementaryPID:UInt16 = 0
    var ESInfoLength:UInt16 = 0
    var ESDescriptors:[UInt8] = []

    init() {
    }

    init?(bytes:[UInt8]) {
        self.bytes = bytes
    }
}

extension ElementaryStreamSpecificData: BytesConvertible {
    // MARK: BytesConvertible
    var bytes:[UInt8] {
        get {
            return ByteArray()
                .writeUInt8(streamType)
                .writeUInt16(elementaryPID | 0xe000)
                .writeUInt16(ESInfoLength | 0xf000)
                .writeBytes(ESDescriptors)
                .bytes
        }
        set {
            let buffer:ByteArray = ByteArray(bytes: newValue)
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

extension ElementaryStreamSpecificData: CustomStringConvertible {
    // MARK: CustomStringConvertible
    var description:String {
        return Mirror(reflecting: self).description
    }
}
