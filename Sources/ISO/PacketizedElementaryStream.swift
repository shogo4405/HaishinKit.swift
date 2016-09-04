import Foundation
import AVFoundation

/**
 - seealso: https://en.wikipedia.org/wiki/Packetized_elementary_stream
 */
protocol PESPacketHeader {
    var startCode:[UInt8] { get set }
    var streamID:UInt8 { get set }
    var packetLength:UInt16 { get set }
    var optionalPESHeader:PESOptionalHeader? { get set }
    var data:[UInt8] { get set }
}

// MARK: -
enum PESPTSDTSIndicator:UInt8 {
    case none        = 0
    case onlyPTS     = 1
    case forbidden   = 2
    case bothPresent = 3
}

// MARK: -
struct PESOptionalHeader {
    static internal let fixedSectionSize:Int = 3
    static internal let defaultMarkerBits:UInt8 = 2

    internal var markerBits:UInt8 = PESOptionalHeader.defaultMarkerBits
    internal var scramblingControl:UInt8 = 0
    internal var priority:Bool = false
    internal var dataAlignmentIndicator:Bool = false
    internal var copyright:Bool = false
    internal var originalOrCopy:Bool = false
    internal var PTSDTSIndicator:UInt8 = PESPTSDTSIndicator.none.rawValue
    internal var ESCRFlag:Bool = false
    internal var ESRateFlag:Bool = false
    internal var DSMTrickModeFlag:Bool = false
    internal var additionalCopyInfoFlag:Bool = false
    internal var CRCFlag:Bool = false
    internal var extentionFlag:Bool = false
    internal var PESHeaderLength:UInt8 = 0
    internal var optionalFields:[UInt8] = []
    internal var stuffingBytes:[UInt8] = []

    internal init() {
    }

    internal init?(bytes:[UInt8]) {
        self.bytes = bytes
    }

    mutating internal func setTimestamp(_ timestamp:CMTime, presentationTimeStamp:CMTime, decodeTimeStamp:CMTime) {
        let base:Double = Double(timestamp.seconds)
        if (presentationTimeStamp != kCMTimeInvalid) {
            PTSDTSIndicator |= 0x02
        }
        if (decodeTimeStamp != kCMTimeInvalid && presentationTimeStamp != decodeTimeStamp) {
            PTSDTSIndicator |= 0x01
        }
        if (PTSDTSIndicator & 0x02 == 0x02) {
            let PTS:UInt64 = UInt64((presentationTimeStamp.seconds - base) * Double(TSTimestamp.resolution))
            optionalFields += TSTimestamp.encode(PTS, PTSDTSIndicator << 4)
        }
        if (PTSDTSIndicator & 0x01 == 0x01) {
            let DTS:UInt64 = UInt64((decodeTimeStamp.seconds - base) * Double(TSTimestamp.resolution))
            optionalFields += TSTimestamp.encode(DTS, 0x01 << 4)
        }
        PESHeaderLength = UInt8(optionalFields.count)
    }
}

extension PESOptionalHeader: BytesConvertible {
    // MARK: BytesConvertible
    internal var bytes:[UInt8] {
        get {
            var bytes:[UInt8] = [0x00, 0x00]
            bytes[0] |= markerBits << 6
            bytes[0] |= scramblingControl << 4
            bytes[0] |= (priority ? 1 : 0) << 3
            bytes[0] |= (copyright ? 1 : 0) << 2
            bytes[0] |= (originalOrCopy ? 1 : 0)
            bytes[1] |= PTSDTSIndicator << 6
            bytes[1] |= (ESCRFlag ? 1 : 0) << 5
            bytes[1] |= (ESRateFlag ? 1 : 0) << 4
            bytes[1] |= (DSMTrickModeFlag ? 1 : 0) << 3
            bytes[1] |= (additionalCopyInfoFlag ? 1 : 0) << 2
            bytes[1] |= (CRCFlag ? 1 : 0) << 1
            bytes[1] |= extentionFlag ? 1 : 0
            return ByteArray()
                .writeBytes(bytes)
                .writeUInt8(PESHeaderLength)
                .writeBytes(optionalFields)
                .writeBytes(stuffingBytes)
                .bytes
        }
        set {
            let buffer:ByteArray = ByteArray(bytes: newValue)
            do {
                var bytes:[UInt8] = try buffer.readBytes(PESOptionalHeader.fixedSectionSize)
                markerBits = (bytes[0] & 0b11000000) >> 6
                scramblingControl = bytes[0] & 0b00110000 >> 4
                priority = bytes[0] & 0b00001000 == 0b00001000
                dataAlignmentIndicator = bytes[0] & 0b00000100 == 0b00000100
                copyright = bytes[0] & 0b00000010 == 0b00000010
                originalOrCopy = bytes[0] & 0b00000001 == 0b00000001
                PTSDTSIndicator = (bytes[1] & 0b11000000) >> 6
                ESCRFlag = bytes[1] & 0b00100000 == 0b00100000
                ESRateFlag = bytes[1] & 0b00010000 == 0b00010000
                DSMTrickModeFlag = bytes[1] & 0b00001000 == 0b00001000
                additionalCopyInfoFlag = bytes[1] & 0b00000100 == 0b00000100
                CRCFlag = bytes[1] & 0b00000010 == 0b00000010
                extentionFlag = bytes[1] & 0b00000001 == 0b00000001
                PESHeaderLength = bytes[2]
                optionalFields = try buffer.readBytes(Int(PESHeaderLength))
            } catch {
                logger.error("\(buffer)")
            }
        }
    }
}

extension PESOptionalHeader: CustomStringConvertible {
    // MARK: CustomStringConvertible
    internal var description:String {
        return Mirror(reflecting: self).description
    }
}

// MARK: -
struct PacketizedElementaryStream: PESPacketHeader {
    static internal let untilPacketLengthSize:Int = 6
    static internal let startCode:[UInt8] = [0x00, 0x00, 0x01]

    static internal func create(_ sampleBuffer:CMSampleBuffer, timestamp:CMTime, config:Any?) -> PacketizedElementaryStream? {
        if let config:AudioSpecificConfig = config as? AudioSpecificConfig {
            return PacketizedElementaryStream(sampleBuffer: sampleBuffer, timestamp: timestamp, config: config)
        }
        if let config:AVCConfigurationRecord = config as? AVCConfigurationRecord {
            return PacketizedElementaryStream(sampleBuffer: sampleBuffer, timestamp: timestamp, config: sampleBuffer.dependsOnOthers ? nil : config)
        }
        return nil
    }

    internal var startCode:[UInt8] = PacketizedElementaryStream.startCode
    internal var streamID:UInt8 = 0
    internal var packetLength:UInt16 = 0
    internal var optionalPESHeader:PESOptionalHeader?
    internal var data:[UInt8] = []

    internal init?(bytes:[UInt8]) {
        self.bytes = bytes
        if (startCode != PacketizedElementaryStream.startCode) {
            return nil
        }
    }

    internal init?(sampleBuffer:CMSampleBuffer, timestamp:CMTime, config:AudioSpecificConfig?) {
        let payload:[UInt8] = sampleBuffer.bytes
        data += config!.adts(payload.count)
        data += payload
        optionalPESHeader = PESOptionalHeader()
        optionalPESHeader?.setTimestamp(
            timestamp,
            presentationTimeStamp: sampleBuffer.presentationTimeStamp,
            decodeTimeStamp: sampleBuffer.decodeTimeStamp
        )
        packetLength = UInt16(data.count + optionalPESHeader!.bytes.count)
    }

    internal init?(sampleBuffer:CMSampleBuffer, timestamp:CMTime, config:AVCConfigurationRecord?) {
        data += [0x00, 0x00, 0x00, 0x01, 0x09, 0xf0]
        if let config:AVCConfigurationRecord = config {
            data += [0x00, 0x00, 0x00, 0x01] + config.sequenceParameterSets[0]
            data += [0x00, 0x00, 0x00, 0x01] + config.pictureParameterSets[0]
        }
        data += AVCFormatStream(bytes: sampleBuffer.bytes).toByteStream()
        optionalPESHeader = PESOptionalHeader()
        optionalPESHeader?.setTimestamp(
            timestamp,
            presentationTimeStamp: sampleBuffer.presentationTimeStamp,
            decodeTimeStamp: sampleBuffer.decodeTimeStamp
        )
        packetLength = UInt16(data.count + optionalPESHeader!.bytes.count)
    }

    internal func arrayOfPackets(_ PID:UInt16, PCR:UInt64?) -> [TSPacket] {
        let payload:[UInt8] = bytes
        var packets:[TSPacket] = []

        // start
        var packet:TSPacket = TSPacket()
        packet.PID = PID
        if let PCR:UInt64 = PCR {
            packet.adaptationFieldFlag = true
            packet.adaptationField = TSAdaptationField()
            packet.adaptationField?.PCRFlag = true
            packet.adaptationField?.PCR = TSProgramClockReference.encode(0, UInt16(PCR))
            packet.adaptationField?.compute()
        }
        packet.payloadUnitStartIndicator = true
        let position:Int = packet.fill(payload, useAdaptationField: true)
        packets.append(packet)

        // middle
        let r:Int = (payload.count - position) % 184
        for index in stride(from: payload.startIndex.advanced(by: position), to: payload.endIndex.advanced(by: -r), by: 184) {
            var packet:TSPacket = TSPacket()
            packet.PID = PID
            packet.payloadFlag = true
            packet.payload = Array(payload[index..<index.advanced(by: 184)])
            packets.append(packet)
        }

        switch r {
        case 0:
            break
        case 183:
            let remain:[UInt8] = Array(payload[payload.endIndex - r..<payload.endIndex - 1])
            var packet:TSPacket = TSPacket()
            packet.PID = PID
            packet.adaptationFieldFlag = true
            packet.adaptationField = TSAdaptationField()
            packet.adaptationField?.compute()
            let _ = packet.fill(remain, useAdaptationField: true)
            packets.append(packet)
            packet = TSPacket()
            packet.PID = PID
            packet.adaptationFieldFlag = true
            packet.adaptationField = TSAdaptationField()
            packet.adaptationField?.compute()
            let _ = packet.fill([payload[payload.count - 1]], useAdaptationField: true)
            packets.append(packet)
        default:
            let remain:[UInt8] = Array(payload[payload.indices.suffix(from: payload.endIndex - r)])
            var packet:TSPacket = TSPacket()
            packet.PID = PID
            packet.adaptationFieldFlag = true
            packet.adaptationField = TSAdaptationField()
            packet.adaptationField?.compute()
            let _ = packet.fill(remain, useAdaptationField: true)
            packets.append(packet)
        }

        return packets
    }

    mutating internal func append(_ bytes:[UInt8]) -> Int {
        data += bytes
        return bytes.count
    }
}

extension PacketizedElementaryStream: BytesConvertible {
    // MARK: BytesConvertible
    internal var bytes:[UInt8] {
        get {
            return ByteArray()
                .writeBytes(startCode)
                .writeUInt8(streamID)
                .writeUInt16(packetLength)
                .writeBytes(optionalPESHeader?.bytes ?? [])
                .writeBytes(data)
                .bytes
        }
        set {
            let buffer:ByteArray = ByteArray(bytes: newValue)
            do {
                startCode = try buffer.readBytes(3)
                streamID = try buffer.readUInt8()
                packetLength = try buffer.readUInt16()
                optionalPESHeader = PESOptionalHeader(bytes: try buffer.readBytes(buffer.bytesAvailable))
                if let optionalPESHeader:PESOptionalHeader = optionalPESHeader {
                    buffer.position = PacketizedElementaryStream.untilPacketLengthSize + 3 + Int(optionalPESHeader.PESHeaderLength)
                } else {
                    buffer.position = PacketizedElementaryStream.untilPacketLengthSize
                }
                data = try buffer.readBytes(buffer.bytesAvailable)
            } catch {
                logger.error("\(buffer)")
            }
        }
    }
}

extension PacketizedElementaryStream: CustomStringConvertible {
    // MARK: CustomStringConvertible
    internal var description:String {
        return Mirror(reflecting: self).description
    }
}
