import Foundation

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
                continue
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
