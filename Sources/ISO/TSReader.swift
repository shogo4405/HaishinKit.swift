import Foundation

protocol TSReaderDelegate: class {
    func didReadPacketizedElementaryStream(_ data:ElementaryStreamSpecificData, PES:PacketizedElementaryStream)
}

// MARK: -
class TSReader {
    weak var delegate:TSReaderDelegate?

    fileprivate(set) var PAT:ProgramAssociationSpecific? {
        didSet {
            guard let PAT:ProgramAssociationSpecific = PAT else {
                return
            }
            for (channel, PID) in PAT.programs {
                dictionaryForPrograms[PID] = channel
            }
        }
    }
    fileprivate(set) var PMT:[UInt16: ProgramMapSpecific] = [:] {
        didSet {
            for (_, pmt) in PMT {
                for data in pmt.elementaryStreamSpecificData {
                    dictionaryForESSpecData[data.elementaryPID] = data
                }
            }
        }
    }
    fileprivate(set) var numberOfPackets:Int = 0

    fileprivate var eof:UInt64 = 0
    fileprivate var cursor:Int = 0
    fileprivate var fileHandle:FileHandle?
    fileprivate var dictionaryForPrograms:[UInt16:UInt16] = [:]
    fileprivate var dictionaryForESSpecData:[UInt16:ElementaryStreamSpecificData] = [:]
    fileprivate var packetizedElementaryStreams:[UInt16:PacketizedElementaryStream] = [:]

    init(url:URL) throws {
        fileHandle = try FileHandle(forReadingFrom: url)
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

    func readPacketizedElementaryStream(_ data:ElementaryStreamSpecificData, packet: TSPacket) {
        if (packet.payloadUnitStartIndicator) {
            if let PES:PacketizedElementaryStream = packetizedElementaryStreams[packet.PID] {
                delegate?.didReadPacketizedElementaryStream(data, PES: PES)
            }
            packetizedElementaryStreams[packet.PID] = PacketizedElementaryStream(bytes: packet.payload)
            return
        }
        let _:Int? = packetizedElementaryStreams[packet.PID]?.append(packet.payload)
    }

    func close() {
        fileHandle?.closeFile()
    }
}

extension TSReader: Iterator {
    // MARK: Iterator
    typealias T = TSPacket

    func next() -> TSPacket? {
        guard let fileHandle = fileHandle else {
            return nil
        }
        defer {
            cursor += 1
        }
        fileHandle.seek(toFileOffset: UInt64(cursor * TSPacket.size))
        return TSPacket(data: fileHandle.readData(ofLength: TSPacket.size))
    }

    func hasNext() -> Bool {
        return UInt64(cursor * TSPacket.size) < eof
    }
}

extension TSReader: CustomStringConvertible {
    // MARK: CustomStringConvertible
    var description:String {
        return Mirror(reflecting: self).description
    }
}
