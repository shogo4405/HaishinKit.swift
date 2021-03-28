import Foundation

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
