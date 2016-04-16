import Foundation

/*
 - seealso: https://en.wikipedia.org/wiki/Program-specific_information
 */
protocol PSIPointer {
    var pointerField:UInt8 { get set }
    var pointerFillerBytes:[UInt8] { get set }
}

protocol PSITableHeader {
    var tableID:UInt8 { get set }
    var sectionSyntaxIndicator:Bool { get set }
    var privateBit:Bool { get set }
    var sectionLength:UInt16 { get set }
}

protocol PSITableSyntax {
    var tableIDExtension:UInt16 { get set }
    var versionNumber:UInt8 { get set }
    var currentNextIndicator:Bool { get set }
    var sectionNumber:UInt8 { get set }
    var lastSectionNumber:UInt8 { get set }
    var data:[UInt8] { get set }
    var CRC32:[UInt8] { get set }
}

// MARK: - ProgramSpecific
class ProgramSpecific: PSIPointer, PSITableHeader, PSITableSyntax {
    static let reservedBits:UInt8 = 0x03

    // MARK: PSIPointer
    var pointerField:UInt8 = 0
    var pointerFillerBytes:[UInt8] = []

    // MARK: PSITableHeader
    var tableID:UInt8 = 0
    var sectionSyntaxIndicator:Bool = false
    var privateBit:Bool = false
    var sectionLength:UInt16 = 0

    // MARK: PSITableSyntax
    var tableIDExtension:UInt16 = 0
    var versionNumber:UInt8 = 0
    var currentNextIndicator:Bool = false
    var sectionNumber:UInt8 = 0
    var lastSectionNumber:UInt8 = 0
    var data:[UInt8] {
        get {
            return []
        }
        set {
            
        }
    }
    var CRC32:[UInt8] = []

    init?(bytes: [UInt8]) {
        self.bytes = bytes
    }
}

// MARK: CustomStringConvertible
extension ProgramSpecific: CustomStringConvertible {
    var description:String {
        return Mirror(reflecting: self).description
    }
}

// MARK: BytesConvertible
extension ProgramSpecific: BytesConvertible {
    var bytes:[UInt8] {
        get {
            return ByteArray()
                .writeUInt8(pointerField)
                .writeBytes(pointerFillerBytes)
                .writeUInt8(tableID)
                .writeUInt16(
                    (sectionSyntaxIndicator ? 1 : 0) << 15 |
                    (privateBit ? 1 : 0) << 14 |
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
                .writeBytes(CRC32)
                .bytes
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
                CRC32 = try buffer.readBytes(4)
            } catch {
                logger.error("\(buffer)")
            }
        }
    }
}

// MARK: - ProgramAssociationSpecific
final class ProgramAssociationSpecific: ProgramSpecific {
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

// MARK: - ProgramMapSpecific
final class ProgramMapSpecific: ProgramSpecific {
    static let unusedPCRID:UInt16 = 0x1fff

    var PCRPID:UInt16 = 0
    var programInfoLength:UInt16 = 0
    var elementaryStreamSpecificData:[ElementaryStreamSpecificData] = []

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
                for _ in 0..<programInfoLength / 8 {
                    buffer.position += 8
                }
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

// MARK: - ElementaryStreamSpecificData
struct ElementaryStreamSpecificData {
    static let fixedHeaderSize:Int = 5

    var streamType:UInt8 = 0
    var elementaryPID:UInt16 = 0
    var ESInfoLength:UInt16 = 0
    var ESDescriptors:[UInt8] = []

    init?(bytes: [UInt8]) {
        self.bytes = bytes
    }
}

// MARK: BytesConvertible
extension ElementaryStreamSpecificData: BytesConvertible {
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

// MARK: CustomStringConvertible
extension ElementaryStreamSpecificData: CustomStringConvertible {
    var description:String {
        return Mirror(reflecting: self).description
    }
}
