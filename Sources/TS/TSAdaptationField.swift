import Foundation

class TSAdaptationField {
    static let PCRSize: Int = 6
    static let fixedSectionSize: Int = 2

    var length: UInt8 = 0
    var discontinuityIndicator = false
    var randomAccessIndicator = false
    var elementaryStreamPriorityIndicator = false
    var PCRFlag = false
    var OPCRFlag = false
    var splicingPointFlag = false
    var transportPrivateDataFlag = false
    var adaptationFieldExtensionFlag = false
    var PCR = Data()
    var OPCR = Data()
    var spliceCountdown: UInt8 = 0
    var transportPrivateDataLength: UInt8 = 0
    var transportPrivateData = Data()
    var adaptationExtension: TSAdaptationExtensionField?
    var stuffingBytes = Data()

    init() {
    }

    init?(data: Data) {
        self.data = data
    }

    func compute() {
        length = UInt8(truncatingIfNeeded: TSAdaptationField.fixedSectionSize)
        length += UInt8(truncatingIfNeeded: PCR.count)
        length += UInt8(truncatingIfNeeded: OPCR.count)
        length += UInt8(truncatingIfNeeded: transportPrivateData.count)
        if let adaptationExtension: TSAdaptationExtensionField = adaptationExtension {
            length += adaptationExtension.length + 1
        }
        length += UInt8(truncatingIfNeeded: stuffingBytes.count)
        length -= 1
    }

    func stuffing(_ size: Int) {
        stuffingBytes = Data(repeating: 0xff, count: size)
        length += UInt8(size)
    }
}

extension TSAdaptationField: DataConvertible {
    // MARK: DataConvertible
    var data: Data {
        get {
            var byte: UInt8 = 0
            byte |= discontinuityIndicator ? 0x80 : 0
            byte |= randomAccessIndicator ? 0x40 : 0
            byte |= elementaryStreamPriorityIndicator ? 0x20 : 0
            byte |= PCRFlag ? 0x10 : 0
            byte |= OPCRFlag ? 0x08 : 0
            byte |= splicingPointFlag ? 0x04 : 0
            byte |= transportPrivateDataFlag ? 0x02 : 0
            byte |= adaptationFieldExtensionFlag ? 0x01 : 0
            let buffer = ByteArray()
                .writeUInt8(length)
                .writeUInt8(byte)
            if PCRFlag {
                buffer.writeBytes(PCR)
            }
            if OPCRFlag {
                buffer.writeBytes(OPCR)
            }
            if splicingPointFlag {
                buffer.writeUInt8(spliceCountdown)
            }
            if transportPrivateDataFlag {
                buffer.writeUInt8(transportPrivateDataLength).writeBytes(transportPrivateData)
            }
            if adaptationFieldExtensionFlag {
                buffer.writeBytes(adaptationExtension!.data)
            }
            return buffer.writeBytes(stuffingBytes).data
        }
        set {
            let buffer = ByteArray(data: newValue)
            do {
                length = try buffer.readUInt8()
                let byte: UInt8 = try buffer.readUInt8()
                discontinuityIndicator = (byte & 0x80) == 0x80
                randomAccessIndicator = (byte & 0x40) == 0x40
                elementaryStreamPriorityIndicator = (byte & 0x20) == 0x20
                PCRFlag = (byte & 0x10) == 0x10
                OPCRFlag = (byte & 0x08) == 0x08
                splicingPointFlag = (byte & 0x04) == 0x04
                transportPrivateDataFlag = (byte & 0x02) == 0x02
                adaptationFieldExtensionFlag = (byte & 0x01) == 0x01
                if PCRFlag {
                    PCR = try buffer.readBytes(TSAdaptationField.PCRSize)
                }
                if OPCRFlag {
                    OPCR = try buffer.readBytes(TSAdaptationField.PCRSize)
                }
                if splicingPointFlag {
                    spliceCountdown = try buffer.readUInt8()
                }
                if transportPrivateDataFlag {
                    transportPrivateDataLength = try buffer.readUInt8()
                    transportPrivateData = try buffer.readBytes(Int(transportPrivateDataLength))
                }
                if adaptationFieldExtensionFlag {
                    let length = Int(try buffer.readUInt8())
                    buffer.position -= 1
                    adaptationExtension = TSAdaptationExtensionField(data: try buffer.readBytes(length + 1))
                }
                stuffingBytes = try buffer.readBytes(buffer.bytesAvailable)
            } catch {
                logger.error("\(buffer)")
            }
        }
    }
}

extension TSAdaptationField: CustomDebugStringConvertible {
    // MARK: CustomDebugStringConvertible
    var debugDescription: String {
        Mirror(reflecting: self).debugDescription
    }
}
