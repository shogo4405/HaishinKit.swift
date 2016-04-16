import Foundation

/**
 - seealso: https://en.wikipedia.org/wiki/MPEG_transport_stream#Packet
 */
struct TSPacket {
    static let size:Int = 188
    static let defaultSyncByte:UInt8 = 0x47
    static let defaultPID:UInt16 = 0
    static let defaultScramblingControl:UInt8 = 0
    static let defaultContinuityCounter:UInt8 = 0

    var syncByte:UInt8 = TSPacket.defaultSyncByte
    var transportErrorIndicator:Bool = false
    var payloadUnitStartIndicator:Bool = false
    var transportPriority:Bool = false
    var PID:UInt16 = TSPacket.defaultPID
    var scramblingControl:UInt8 = TSPacket.defaultScramblingControl
    var adaptationFieldFlag:Bool = false
    var payloadFlag:Bool = false
    var continuityCounter:UInt8 = TSPacket.defaultContinuityCounter
    var adaptationField:TSAdaptationField?
    var payload:[UInt8] = []

    init?(bytes: [UInt8]) {
        guard TSPacket.size == bytes.count else {
            return nil
        }
        self.bytes = bytes
        if (syncByte != TSPacket.defaultSyncByte) {
            return nil
        }
    }

    init?(data: NSData) {
        guard TSPacket.size == data.length else {
            return nil
        }
        self.bytes = data.arrayOfBytes()
        if (syncByte != TSPacket.defaultSyncByte) {
            return nil
        }
    }
}

// MARK: BytesConvertible
extension TSPacket: BytesConvertible {
    var bytes:[UInt8] {
        get {
            var bytes:[UInt8] = [syncByte, 0x00, 0x00, 0x00]
            bytes[1] |= (transportErrorIndicator ? 1 : 0) << 7
            bytes[1] |= (payloadUnitStartIndicator ? 1 : 0) << 6
            bytes[1] |= (transportPriority ? 1 : 0) << 5
            bytes[1] |= UInt8(PID >> 8)
            bytes[2] |= UInt8(PID)
            bytes[3] |= scramblingControl << 6
            bytes[3] |= (adaptationFieldFlag ? 1 : 0) << 5
            bytes[3] |= (payloadFlag ? 1 : 0) << 4
            bytes[3] |= continuityCounter
            return ByteArray()
                .writeBytes(bytes)
                .writeBytes(adaptationFieldFlag ? adaptationField!.bytes : [])
                .writeBytes(payload)
                .bytes
        }
        set {
            let buffer:ByteArray = ByteArray(bytes: newValue)
            do {
                var data:[UInt8] = try buffer.readBytes(4)
                syncByte = data[0]
                transportErrorIndicator = data[1] & 0x80 == 0x80
                payloadUnitStartIndicator = data[1] & 0x40 == 0x40
                transportPriority = data[1] & 0x20 == 0x20
                PID = UInt16(data[1] & 0x1f) << 8 | UInt16(data[2])
                scramblingControl = UInt8(data[3] & 0xc0)
                adaptationFieldFlag = data[3] & 0x20 == 0x20
                payloadFlag = data[3] & 0x10 == 0x10
                continuityCounter = UInt8(data[3] & 0xf)
                if (adaptationFieldFlag) {
                    let length:Int = Int(try buffer.readUInt8())
                    buffer.position -= 1
                    adaptationField = TSAdaptationField(bytes: try buffer.readBytes(length + 1))
                }
                if (payloadFlag) {
                    payload = try buffer.readBytes(buffer.bytesAvailable)
                }
            } catch {
                logger.error("\(buffer)")
            }
        }
    }
}

// MARK: CustomStringConvertible
extension TSPacket: CustomStringConvertible {
    var description:String {
        return Mirror(reflecting: self).description
    }
}

// MARK: - TSAdaptationField
struct TSAdaptationField {
    static let PCRSize:Int = 6
    static let OPCRSize:Int = 6

    var length:UInt8 = 0
    var discontinuityIndicator:Bool = false
    var randomAccessIndicator:Bool = false
    var elementaryStreamPriorityIndicator = false
    var PCRFlag:Bool = false
    var OPCRFlag:Bool = false
    var splicingPointFlag:Bool = false
    var transportPrivateDataFlag:Bool = false
    var adaptationFieldExtensionFlag:Bool = false
    var PCR:[UInt8] = []
    var OPCR:[UInt8] = []
    var spliceCountdown:UInt8 = 0
    var transportPrivateDataLength:UInt8 = 0
    var transportPrivateData:[UInt8] = []
    var adaptationExtension:TSAdaptationExtensionField?
    var stuffingBytes:[UInt8] = []

    init?(bytes: [UInt8]) {
        self.bytes = bytes
    }
}

// MARK: BytesConvertible
extension TSAdaptationField: BytesConvertible {
    var bytes:[UInt8] {
        get {
            let buffer:ByteArray = ByteArray()
            return buffer.bytes
        }
        set {
            let buffer:ByteArray = ByteArray(bytes: newValue)
            do {
                var byte:UInt8 = 0
                length = try buffer.readUInt8()
                byte = try buffer.readUInt8()
                discontinuityIndicator = byte & 0x80 == 0x80
                randomAccessIndicator = byte & 0x40 == 0x40
                elementaryStreamPriorityIndicator = byte & 0x20 == 0x20
                PCRFlag = byte & 0x10 == 0x10
                OPCRFlag = byte & 0x08 == 0x08
                splicingPointFlag = byte & 0x04 == 0x04
                transportPrivateDataFlag = byte & 0x02 == 0x02
                adaptationFieldExtensionFlag = byte & 0x01 == 0x01
                if (PCRFlag) {
                    PCR = try buffer.readBytes(TSAdaptationField.PCRSize)
                }
                if (OPCRFlag) {
                    OPCR = try buffer.readBytes(TSAdaptationField.OPCRSize)
                }
                if (splicingPointFlag) {
                    spliceCountdown = try buffer.readUInt8()
                }
                if (transportPrivateDataFlag) {
                    transportPrivateDataLength = try buffer.readUInt8()
                    transportPrivateData = try buffer.readBytes(Int(transportPrivateDataLength))
                }
                if (adaptationFieldExtensionFlag) {
                    let length:Int = Int(try buffer.readUInt8())
                    buffer.position -= 1
                    adaptationExtension = TSAdaptationExtensionField(bytes: try buffer.readBytes(length + 1))
                }
                stuffingBytes = try buffer.readBytes(buffer.bytesAvailable)
            } catch {
                logger.error("\(buffer)")
            }
        }
    }
}

// MARK: CustomStringConvertible
extension TSAdaptationField: CustomStringConvertible {
    var description:String {
        return Mirror(reflecting: self).description
    }
}

// MARK: - TSAdaptationExtensionField
struct TSAdaptationExtensionField {
    var length:UInt8 = 0
    var legalTimeWindowFlag:Bool = false
    var piecewiseRateFlag:Bool = false
    var seamlessSpiceFlag:Bool = false
    var legalTimeWindowValidFlag:Bool = false
    var legalTimeWindowOffset:UInt16 = 0
    var piecewiseRate:UInt32 = 0
    var spliceType:UInt8 = 0
    var DTSNextAccessUnit:[UInt8] = [UInt8](count: 5, repeatedValue: 0x00)

    init?(bytes: [UInt8]) {
        self.bytes = bytes
    }
}

// MARK: BytesConvertible
extension TSAdaptationExtensionField: BytesConvertible {
    var bytes:[UInt8] {
        get {
            let buffer:ByteArray = ByteArray()
                .writeUInt8(length)
                .writeUInt8(
                    (legalTimeWindowFlag ? 1 : 0) << 7 |
                    (piecewiseRateFlag ? 1 : 0) << 6 |
                    (seamlessSpiceFlag ? 1 : 0) << 5
                )
            if (legalTimeWindowFlag) {
                buffer
                    .writeUInt16((legalTimeWindowFlag ? 1 : 0) << 15 | legalTimeWindowOffset)
            }
            if (piecewiseRateFlag) {
                buffer
                    .writeUInt24(piecewiseRate)
            }
            if (seamlessSpiceFlag) {
                buffer
                    .writeUInt8(spliceType)
                    .writeUInt8(spliceType << 4 | DTSNextAccessUnit[0])
                    .writeBytes(Array(DTSNextAccessUnit[1..<DTSNextAccessUnit.count]))
            }
            return buffer.bytes
        }
        set {
            let buffer:ByteArray = ByteArray(bytes: newValue)
            do {
                var byte:UInt8 = 0
                length = try buffer.readUInt8()
                byte = try buffer.readUInt8()
                legalTimeWindowFlag = (byte & 0x80) == 0x80
                piecewiseRateFlag = (byte & 0x40) == 0x40
                seamlessSpiceFlag = (byte & 0x1f) == 0x1f
                if (legalTimeWindowFlag) {
                    legalTimeWindowOffset = try buffer.readUInt16()
                    legalTimeWindowFlag = (legalTimeWindowOffset & 0x8000) == 0x8000
                }
                if (piecewiseRateFlag) {
                    piecewiseRate = try buffer.readUInt24()
                }
                if (seamlessSpiceFlag) {
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

// MARK: CustomStringConvertible
extension TSAdaptationExtensionField: CustomStringConvertible {
    var description:String {
        return Mirror(reflecting: self).description
    }
}

// MARK: - TSReaderDelegate
protocol TSReaderDelegate: class {
    func didReadPacketizedElementaryStream(data:ElementaryStreamSpecificData, PES:PacketizedElementaryStream)
}

// MARK: - TSReader
class TSReader {
    weak var delegate:TSReaderDelegate?

    private var eof:UInt64 = 0
    private var cursor:Int = 0
    private var fileHandle:NSFileHandle?

    private(set) var PAT:ProgramAssociationSpecific? {
        didSet {
            guard let PAT:ProgramAssociationSpecific = PAT else {
                return
            }
            for (channel, PID) in PAT.programs {
                dictionaryForPrograms[PID] = channel
            }
        }
    }
    private(set) var PMT:[UInt16: ProgramMapSpecific] = [:] {
        didSet {
            for (_, pmt) in PMT {
                for data in pmt.elementaryStreamSpecificData {
                    dictionaryForESSpecData[data.elementaryPID] = data
                }
            }
        }
    }
    private(set) var numberOfPackets:Int = 0

    private var dictionaryForPrograms:[UInt16: UInt16] = [:]
    private var dictionaryForESSpecData:[UInt16: ElementaryStreamSpecificData] = [:]
    private var packetizedElementaryStreams:[UInt16: PacketizedElementaryStream] = [:]

    init(url:NSURL) throws {
        fileHandle = try NSFileHandle(forReadingFromURL: url)
        eof = fileHandle!.seekToEndOfFile()
    }

    func read() {
        while (hasNext()) {
            guard let packet:TSPacket = next() else {
                continue
            }
            numberOfPackets += 1

            if (packet.PID == 0x0000) {
                PAT = ProgramAssociationSpecific(bytes: packet.payload)
                continue
            }

            if let channel:UInt16 = dictionaryForPrograms[packet.PID] {
                PMT[channel] = ProgramMapSpecific(bytes: packet.payload)
            }

            if let data:ElementaryStreamSpecificData = dictionaryForESSpecData[packet.PID] {
                readPacketizedElementaryStream(data, packet: packet)
            }
        }
    }

    func readPacketizedElementaryStream(data:ElementaryStreamSpecificData, packet: TSPacket) {
        if (packet.payloadUnitStartIndicator) {
            if let PES:PacketizedElementaryStream = packetizedElementaryStreams[packet.PID] {
                delegate?.didReadPacketizedElementaryStream(data, PES: PES)
            }
            packetizedElementaryStreams[packet.PID] = PacketizedElementaryStream(bytes: packet.payload)
            return
        }
        packetizedElementaryStreams[packet.PID]?.append(packet.payload)
    }

    func close() {
        fileHandle?.closeFile()
    }
}

// MARK: Iterator
extension TSReader: Iterator {
    typealias T = TSPacket

    func next() -> TSPacket? {
        guard let fileHandle = fileHandle else {
            return nil
        }
        defer {
            cursor += 1
        }
        fileHandle.seekToFileOffset(UInt64(cursor * TSPacket.size))
        return TSPacket(data: fileHandle.readDataOfLength(TSPacket.size))
    }

    func hasNext() -> Bool {
        return UInt64(cursor * TSPacket.size) < eof
    }
}

// MARK: CustomStringConvertible
extension TSReader: CustomStringConvertible {
    var description:String {
        return Mirror(reflecting: self).description
    }
}
