import Foundation

/*
 - seealso: https://en.wikipedia.org/wiki/Program-specific_information#Table
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
            let buffer:ByteArray = ByteArray()
            return buffer.bytes
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
                privateBit = bytes[0] & 0x00 == 0x00
                sectionLength = UInt16(bytes[0] & 0x03) << 8 | UInt16(bytes[1])
                tableIDExtension = try buffer.readUInt16()
                versionNumber = try buffer.readUInt8()
                currentNextIndicator = versionNumber & 0x01 == 0x01
                versionNumber = versionNumber & 0b00111110 >> 1
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
            return buffer.bytes
        }
        set {
            let buffer:ByteArray = ByteArray(bytes: newValue)
            do {
                for _ in 0..<newValue.count / 4 {
                    let programNumber:UInt16 = try buffer.readUInt16()
                    let bytes = try buffer.readBytes(2)
                    let programMapPID:UInt16 = UInt16(bytes[0] & 0b00011111) << 8 | UInt16(bytes[1])
                    programs[programNumber] = programMapPID
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
            return []
        }
        set {
            let buffer:ByteArray = ByteArray(bytes: newValue)
            do {
                var bytes:[UInt8] = try buffer.readBytes(2)
                PCRPID = UInt16(bytes[0] & 0b00011111) << 8 | UInt16(bytes[1])
                bytes = try buffer.readBytes(2)
                programInfoLength = UInt16(bytes[0] & 0b0000011) << 8 | UInt16(bytes[1])
                for _ in 0..<programInfoLength / 8 {
                    buffer.position += 8
                }
                while (0 < buffer.bytesAvailable) {
                    var data:ElementaryStreamSpecificData = ElementaryStreamSpecificData()
                    data.streamType = try buffer.readUInt8()
                    bytes = try buffer.readBytes(2)
                    data.elementaryPID = UInt16(bytes[0] & 0b00011111) << 8 | UInt16(bytes[1])
                    bytes = try buffer.readBytes(2)
                    data.ESInfoLength = UInt16(bytes[0] & 0b00000011) << 8 | UInt16(bytes[1])
                    data.ESDescriptors = try buffer.readBytes(Int(data.ESInfoLength))
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
    var streamType:UInt8 = 0
    var elementaryPID:UInt16 = 0
    var ESInfoLength:UInt16 = 0
    var ESDescriptors:[UInt8] = []
}

// MARK: CustomStringConvertible
extension ElementaryStreamSpecificData: CustomStringConvertible {
    var description:String {
        return Mirror(reflecting: self).description
    }
}
