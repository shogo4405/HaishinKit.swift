import Foundation

/**
 - seealso: https://en.wikipedia.org/wiki/Program-specific_information
 */
protocol PSIPointer {
    var pointerField: UInt8 { get set }
    var pointerFillerBytes: Data { get set }
}

// MARK: -
protocol PSITableHeader {
    var tableID: UInt8 { get set }
    var sectionSyntaxIndicator: Bool { get set }
    var privateBit: Bool { get set }
    var sectionLength: UInt16 { get set }
}

// MARK: -
protocol PSITableSyntax {
    var tableIDExtension: UInt16 { get set }
    var versionNumber: UInt8 { get set }
    var currentNextIndicator: Bool { get set }
    var sectionNumber: UInt8 { get set }
    var lastSectionNumber: UInt8 { get set }
    var tableData: Data { get set }
    var crc32: UInt32 { get set }
}

// MARK: -
class ProgramSpecific: PSIPointer, PSITableHeader, PSITableSyntax {
    static let reservedBits: UInt8 = 0x03
    static let defaultTableIDExtension: UInt16 = 1

    // MARK: PSIPointer
    var pointerField: UInt8 = 0
    var pointerFillerBytes = Data()

    // MARK: PSITableHeader
    var tableID: UInt8 = 0
    var sectionSyntaxIndicator = false
    var privateBit = false
    var sectionLength: UInt16 = 0

    // MARK: PSITableSyntax
    var tableIDExtension: UInt16 = ProgramSpecific.defaultTableIDExtension
    var versionNumber: UInt8 = 0
    var currentNextIndicator = true
    var sectionNumber: UInt8 = 0
    var lastSectionNumber: UInt8 = 0
    var tableData: Data = .init()
    var crc32: UInt32 = 0

    init() {
    }

    init?(_ data: Data) {
        self.data = data
    }

    func arrayOfPackets(_ PID: UInt16) -> [TSPacket] {
        var packets: [TSPacket] = []
        var packet = TSPacket()
        packet.payloadUnitStartIndicator = true
        packet.PID = PID
        _ = packet.fill(data, useAdaptationField: false)
        packets.append(packet)
        return packets
    }
}

extension ProgramSpecific: DataConvertible {
    var data: Data {
        get {
            let tableData: Data = self.tableData
            sectionLength = UInt16(tableData.count) + 9
            sectionSyntaxIndicator = !tableData.isEmpty
            let buffer = ByteArray()
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
                .writeBytes(tableData)
            crc32 = CRC32.MPEG2.calculate(buffer.data)
            return Data([pointerField] + pointerFillerBytes) + buffer.writeUInt32(crc32).data
        }
        set {
            let buffer = ByteArray(data: newValue)
            do {
                pointerField = try buffer.readUInt8()
                pointerFillerBytes = try buffer.readBytes(Int(pointerField))
                tableID = try buffer.readUInt8()
                let bytes: Data = try buffer.readBytes(2)
                sectionSyntaxIndicator = (bytes[0] & 0x80) == 0x80
                privateBit = (bytes[0] & 0x40) == 0x40
                sectionLength = UInt16(bytes[0] & 0x03) << 8 | UInt16(bytes[1])
                tableIDExtension = try buffer.readUInt16()
                versionNumber = try buffer.readUInt8()
                currentNextIndicator = (versionNumber & 0x01) == 0x01
                versionNumber = (versionNumber & 0b00111110) >> 1
                sectionNumber = try buffer.readUInt8()
                lastSectionNumber = try buffer.readUInt8()
                tableData = try buffer.readBytes(Int(sectionLength - 9))
                crc32 = try buffer.readUInt32()
            } catch {
                logger.error("\(buffer)")
            }
        }
    }
}

extension ProgramSpecific: CustomDebugStringConvertible {
    // MARK: CustomDebugStringConvertible
    var debugDescription: String {
        Mirror(reflecting: self).debugDescription
    }
}

// MARK: -
final class ProgramAssociationSpecific: ProgramSpecific {
    static let tableID: UInt8 = 0

    var programs: [UInt16: UInt16] = [:]

    override var tableData: Data {
        get {
            let buffer = ByteArray()
            for (number, programMapPID) in programs {
                buffer.writeUInt16(number).writeUInt16(programMapPID | 0xe000)
            }
            return buffer.data
        }
        set {
            let buffer = ByteArray(data: newValue)
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
    static let tableID: UInt8 = 2
    static let unusedPCRID: UInt16 = 0x1fff

    var PCRPID: UInt16 = 0
    var programInfoLength: UInt16 = 0
    var elementaryStreamSpecificData: [ElementaryStreamSpecificData] = []

    override init() {
        super.init()
        tableID = ProgramMapSpecific.tableID
    }

    override init?(_ data: Data) {
        super.init()
        self.data = data
    }

    override var tableData: Data {
        get {
            var bytes = Data()
            elementaryStreamSpecificData.sort { (lhs: ElementaryStreamSpecificData, rhs: ElementaryStreamSpecificData) -> Bool in
                lhs.elementaryPID < rhs.elementaryPID
            }
            for essd in elementaryStreamSpecificData {
                bytes.append(essd.data)
            }
            return ByteArray()
                .writeUInt16(PCRPID | 0xe000)
                .writeUInt16(programInfoLength | 0xf000)
                .writeBytes(bytes)
                .data
        }
        set {
            let buffer = ByteArray(data: newValue)
            do {
                PCRPID = try buffer.readUInt16() & 0x1fff
                programInfoLength = try buffer.readUInt16() & 0x03ff
                buffer.position += Int(programInfoLength)
                var position = 0
                while 0 < buffer.bytesAvailable {
                    position = buffer.position
                    guard let data = ElementaryStreamSpecificData(try buffer.readBytes(buffer.bytesAvailable)) else {
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
