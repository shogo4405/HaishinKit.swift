import AVFoundation
/**
 - seealso: https://en.wikipedia.org/wiki/MPEG_transport_stream#Packet
 */
struct TSPacket {
    static let size: Int = 188
    static let headerSize: Int = 4
    static let defaultSyncByte: UInt8 = 0x47

    var syncByte: UInt8 = TSPacket.defaultSyncByte
    var transportErrorIndicator = false
    var payloadUnitStartIndicator = false
    var transportPriority = false
    var pid: UInt16 = 0
    var scramblingControl: UInt8 = 0
    var adaptationFieldFlag = false
    var payloadFlag = false
    var continuityCounter: UInt8 = 0
    var adaptationField: TSAdaptationField?
    var payload = Data()

    private var remain: Int {
        var adaptationFieldSize = 0
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
            bytes[1] |= UInt8(pid >> 8)
            bytes[2] |= UInt8(pid & 0x00FF)
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
                let data: Data = try buffer.readBytes(4)
                syncByte = data[0]
                transportErrorIndicator = (data[1] & 0x80) == 0x80
                payloadUnitStartIndicator = (data[1] & 0x40) == 0x40
                transportPriority = (data[1] & 0x20) == 0x20
                pid = UInt16(data[1] & 0x1f) << 8 | UInt16(data[2])
                scramblingControl = UInt8(data[3] & 0xc0)
                adaptationFieldFlag = (data[3] & 0x20) == 0x20
                payloadFlag = (data[3] & 0x10) == 0x10
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

extension TSPacket: CustomDebugStringConvertible {
    // MARK: CustomDebugStringConvertible
    var debugDescription: String {
        Mirror(reflecting: self).debugDescription
    }
}

// MARK: -
enum TSTimestamp {
    static let resolution: Double = 90 * 1000 // 90kHz
    static let dataSize: Int = 5
    static let ptsMask: UInt8 = 0x10
    static let ptsDtsMask: UInt8 = 0x30

    static func decode(_ data: Data, offset: Int = 0) -> Int64 {
        var result: Int64 = 0
        result |= Int64(data[offset + 0] & 0x0e) << 29
        result |= Int64(data[offset + 1]) << 22 | Int64(data[offset + 2] & 0xfe) << 14
        result |= Int64(data[offset + 3]) << 7 | Int64(data[offset + 3] & 0xfe) << 1
        return result
    }

    static func encode(_ b: Int64, _ m: UInt8) -> Data {
        var data = Data(count: dataSize)
        data[0] = UInt8(truncatingIfNeeded: b >> 29) | 0x01 | m
        data[1] = UInt8(truncatingIfNeeded: b >> 22)
        data[2] = UInt8(truncatingIfNeeded: b >> 14) | 0x01
        data[3] = UInt8(truncatingIfNeeded: b >> 7)
        data[4] = UInt8(truncatingIfNeeded: b << 1) | 0x01
        return data
    }
}

// MARK: -
enum TSProgramClockReference {
    static let resolutionForBase: Int32 = 90 * 1000 // 90kHz
    static let resolutionForExtension: Int32 = 27 * 1000 * 1000 // 27MHz

    static func decode(_ data: Data) -> (UInt64, UInt16) {
        var b: UInt64 = 0
        var e: UInt16 = 0
        b |= UInt64(data[0]) << 25
        b |= UInt64(data[1]) << 17
        b |= UInt64(data[2]) << 9
        b |= UInt64(data[3]) << 1
        b |= ((data[4] & 0x80) == 0x80) ? 1 : 0
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
        if (b & 1) == 1 {
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
