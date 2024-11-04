import Foundation

class TSAdaptationField {
    static let PCRSize: Int = 6
    static let fixedSectionSize: Int = 2

    var length: UInt8 = 0
    var discontinuityIndicator = false
    var randomAccessIndicator = false
    var elementaryStreamPriorityIndicator = false
    var pcrFlag = false
    var opcrFlag = false
    var splicingPointFlag = false
    var transportPrivateDataFlag = false
    var adaptationFieldExtensionFlag = false
    var pcr = Data()
    var opcr = Data()
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
        length += UInt8(truncatingIfNeeded: pcr.count)
        length += UInt8(truncatingIfNeeded: opcr.count)
        length += UInt8(truncatingIfNeeded: transportPrivateData.count)
        if let adaptationExtension {
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
            byte |= pcrFlag ? 0x10 : 0
            byte |= opcrFlag ? 0x08 : 0
            byte |= splicingPointFlag ? 0x04 : 0
            byte |= transportPrivateDataFlag ? 0x02 : 0
            byte |= adaptationFieldExtensionFlag ? 0x01 : 0
            let buffer = ByteArray()
                .writeUInt8(length)
                .writeUInt8(byte)
            if pcrFlag {
                buffer.writeBytes(pcr)
            }
            if opcrFlag {
                buffer.writeBytes(opcr)
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
                pcrFlag = (byte & 0x10) == 0x10
                opcrFlag = (byte & 0x08) == 0x08
                splicingPointFlag = (byte & 0x04) == 0x04
                transportPrivateDataFlag = (byte & 0x02) == 0x02
                adaptationFieldExtensionFlag = (byte & 0x01) == 0x01
                if pcrFlag {
                    pcr = try buffer.readBytes(TSAdaptationField.PCRSize)
                }
                if opcrFlag {
                    opcr = try buffer.readBytes(TSAdaptationField.PCRSize)
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

struct TSAdaptationExtensionField {
    var length: UInt8 = 0
    var legalTimeWindowFlag = false
    var piecewiseRateFlag = false
    var seamlessSpiceFlag = false
    var legalTimeWindowOffset: UInt16 = 0
    var piecewiseRate: UInt32 = 0
    var spliceType: UInt8 = 0
    var DTSNextAccessUnit = Data(count: 5)

    init?(data: Data) {
        self.data = data
    }
}

extension TSAdaptationExtensionField: DataConvertible {
    // MARK: DataConvertible
    var data: Data {
        get {
            let buffer = ByteArray()
                .writeUInt8(length)
                .writeUInt8(
                    (legalTimeWindowFlag ? 0x80 : 0) |
                        (piecewiseRateFlag ? 0x40 : 0) |
                        (seamlessSpiceFlag ? 0x1f : 0)
                )
            if legalTimeWindowFlag {
                buffer.writeUInt16((legalTimeWindowFlag ? 0x8000 : 0) | legalTimeWindowOffset)
            }
            if piecewiseRateFlag {
                buffer.writeUInt24(piecewiseRate)
            }
            if seamlessSpiceFlag {
                buffer
                    .writeUInt8(spliceType)
                    .writeUInt8(spliceType << 4 | DTSNextAccessUnit[0])
                    .writeBytes(DTSNextAccessUnit.subdata(in: 1..<DTSNextAccessUnit.count))
            }
            return buffer.data
        }
        set {
            let buffer = ByteArray(data: newValue)
            do {
                var byte: UInt8 = 0
                length = try buffer.readUInt8()
                byte = try buffer.readUInt8()
                legalTimeWindowFlag = (byte & 0x80) == 0x80
                piecewiseRateFlag = (byte & 0x40) == 0x40
                seamlessSpiceFlag = (byte & 0x1f) == 0x1f
                if legalTimeWindowFlag {
                    legalTimeWindowOffset = try buffer.readUInt16()
                    legalTimeWindowFlag = (legalTimeWindowOffset & 0x8000) == 0x8000
                }
                if piecewiseRateFlag {
                    piecewiseRate = try buffer.readUInt24()
                }
                if seamlessSpiceFlag {
                    DTSNextAccessUnit = try buffer.readBytes(DTSNextAccessUnit.count)
                    spliceType = DTSNextAccessUnit[0] & 0xf0 >> 4
                    DTSNextAccessUnit[0] = DTSNextAccessUnit[0] & 0x0f
                }
            } catch {
                logger.error("\(buffer)")
            }
        }
    }
}

extension TSAdaptationExtensionField: CustomDebugStringConvertible {
    // MARK: CustomDebugStringConvertible
    var debugDescription: String {
        Mirror(reflecting: self).debugDescription
    }
}
