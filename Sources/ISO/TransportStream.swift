import AVFoundation
/**
 - seealso: https://en.wikipedia.org/wiki/MPEG_transport_stream#Packet
 */
struct TSPacket {
    static let size: Int = 188
    static let headerSize: Int = 4
    static let defaultSyncByte: UInt8 = 0x47

    var syncByte: UInt8 = TSPacket.defaultSyncByte
    var transportErrorIndicator: Bool = false
    var payloadUnitStartIndicator: Bool = false
    var transportPriority: Bool = false
    var PID: UInt16 = 0
    var scramblingControl: UInt8 = 0
    var adaptationFieldFlag: Bool = false
    var payloadFlag: Bool = false
    var continuityCounter: UInt8 = 0
    var adaptationField: TSAdaptationField?
    var payload = Data()

    private var remain: Int {
        var adaptationFieldSize: Int = 0
        if let adaptationField: TSAdaptationField = adaptationField, adaptationFieldFlag {
            adaptationField.compute()
            adaptationFieldSize = Int(adaptationField.length) + 1
        }
        return TSPacket.size - TSPacket.headerSize - adaptationFieldSize - payload.count
    }

    init() {
    }

    init?(data: Data) {
        guard TSPacket.size == data.count else {
            return nil
        }
        self.data = data
        if syncByte != TSPacket.defaultSyncByte {
            return nil
        }
    }

    mutating func fill(_ data: Data?, useAdaptationField: Bool) -> Int {
        guard let data: Data = data else {
            payload.append(Data(repeating: 0xff, count: remain))
            return 0
        }
        payloadFlag = true
        let length: Int = min(data.count, remain, 182)
        payload.append(data[0..<length])
        if remain == 0 {
            return length
        }
        if useAdaptationField {
            adaptationFieldFlag = true
            if adaptationField == nil {
                adaptationField = TSAdaptationField()
            }
            adaptationField?.stuffing(remain)
            adaptationField?.compute()
            return length
        }
        payload.append(Data(repeating: 0xff, count: remain))
        return length
    }
}

extension TSPacket: DataConvertible {
    // MARK: DataConvertible
    var data: Data {
        get {
            var bytes = Data([syncByte, 0x00, 0x00, 0x00])
            bytes[1] |= transportErrorIndicator ? 0x80 : 0
            bytes[1] |= payloadUnitStartIndicator ? 0x40 : 0
            bytes[1] |= transportPriority ? 0x20 : 0
            bytes[1] |= UInt8(PID >> 8)
            bytes[2] |= UInt8(PID & 0x00FF)
            bytes[3] |= scramblingControl << 6
            bytes[3] |= adaptationFieldFlag ? 0x20 : 0
            bytes[3] |= payloadFlag ? 0x10 : 0
            bytes[3] |= continuityCounter
            return ByteArray()
                .writeBytes(bytes)
                .writeBytes(adaptationFieldFlag ? adaptationField!.data : Data())
                .writeBytes(payload)
                .data
        }
        set {
            let buffer = ByteArray(data: newValue)
            do {
                var data: Data = try buffer.readBytes(4)
                syncByte = data[0]
                transportErrorIndicator = data[1] & 0x80 == 0x80
                payloadUnitStartIndicator = data[1] & 0x40 == 0x40
                transportPriority = data[1] & 0x20 == 0x20
                PID = UInt16(data[1] & 0x1f) << 8 | UInt16(data[2])
                scramblingControl = UInt8(data[3] & 0xc0)
                adaptationFieldFlag = data[3] & 0x20 == 0x20
                payloadFlag = data[3] & 0x10 == 0x10
                continuityCounter = UInt8(data[3] & 0xf)
                if adaptationFieldFlag {
                    let length = Int(try buffer.readUInt8())
                    buffer.position -= 1
                    adaptationField = TSAdaptationField(data: try buffer.readBytes(length + 1))
                }
                if payloadFlag {
                    payload = try buffer.readBytes(buffer.bytesAvailable)
                }
            } catch {
                logger.error("\(buffer)")
            }
        }
    }
}

// MARK: -
struct TSTimestamp {
    static let resolution: Double = 90 * 1000 // 90kHz
    static let PTSMask: UInt8 = 0x10
    static let PTSDTSMask: UInt8 = 0x30

    static func decode(_ data: Data) -> UInt64 {
        var result: UInt64 = 0
        result |= UInt64(data[0] & 0x0e) << 29
        result |= UInt64(data[1]) << 22 | UInt64(data[2] & 0xfe) << 14
        result |= UInt64(data[3]) << 7 | UInt64(data[3] & 0xfe) << 1
        return result
    }

    static func encode(_ b: UInt64, _ m: UInt8) -> Data {
        var data = Data(count: 5)
        data[0] = UInt8(truncatingIfNeeded: b >> 29) | 0x01 | m
        data[1] = UInt8(truncatingIfNeeded: b >> 22)
        data[2] = UInt8(truncatingIfNeeded: b >> 14) | 0x01
        data[3] = UInt8(truncatingIfNeeded: b >> 7)
        data[4] = UInt8(truncatingIfNeeded: b << 1) | 0x01
        return data
    }
}

// MARK: -
struct TSProgramClockReference {
    static let resolutionForBase: Int32 = 90 * 1000 // 90kHz
    static let resolutionForExtension: Int32 = 27 * 1000 * 1000 // 27MHz

    static func decode(_ data: Data) -> (UInt64, UInt16) {
        var b: UInt64 = 0
        var e: UInt16 = 0
        b |= UInt64(data[0]) << 25
        b |= UInt64(data[1]) << 17
        b |= UInt64(data[2]) << 9
        b |= UInt64(data[3]) << 1
        b |= (data[4] & 0x80 == 0x80) ? 1 : 0
        e |= UInt16(data[4] & 0x01) << 8
        e |= UInt16(data[5])
        return (b, e)
    }

    static func encode(_ b: UInt64, _ e: UInt16) -> Data {
        var data = Data(count: 6)
        data[0] = UInt8(truncatingIfNeeded: b >> 25)
        data[1] = UInt8(truncatingIfNeeded: b >> 17)
        data[2] = UInt8(truncatingIfNeeded: b >> 9)
        data[3] = UInt8(truncatingIfNeeded: b >> 1)
        data[4] = 0xff
        if b & 1 == 1 {
            data[4] |= 0x80
        } else {
            data[4] &= 0x7f
        }
        if UInt16(data[4] & 0x01) >> 8 == 1 {
            data[4] |= 1
        } else {
            data[4] &= 0xfe
        }
        data[5] = UInt8(truncatingIfNeeded: e)
        return data
    }
}

// MARK: -
class TSAdaptationField {
    static let PCRSize: Int = 6
    static let fixedSectionSize: Int = 2

    var length: UInt8 = 0
    var discontinuityIndicator: Bool = false
    var randomAccessIndicator: Bool = false
    var elementaryStreamPriorityIndicator = false
    var PCRFlag: Bool = false
    var OPCRFlag: Bool = false
    var splicingPointFlag: Bool = false
    var transportPrivateDataFlag: Bool = false
    var adaptationFieldExtensionFlag: Bool = false
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
                discontinuityIndicator = byte & 0x80 == 0x80
                randomAccessIndicator = byte & 0x40 == 0x40
                elementaryStreamPriorityIndicator = byte & 0x20 == 0x20
                PCRFlag = byte & 0x10 == 0x10
                OPCRFlag = byte & 0x08 == 0x08
                splicingPointFlag = byte & 0x04 == 0x04
                transportPrivateDataFlag = byte & 0x02 == 0x02
                adaptationFieldExtensionFlag = byte & 0x01 == 0x01
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

// MARK: -
struct TSAdaptationExtensionField {
    var length: UInt8 = 0
    var legalTimeWindowFlag: Bool = false
    var piecewiseRateFlag: Bool = false
    var seamlessSpiceFlag: Bool = false
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
