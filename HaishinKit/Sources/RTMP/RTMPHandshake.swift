import Foundation

final class RTMPHandshake {
    static let sigSize: Int = 1536
    static let protocolVersion: UInt8 = 3

    var timestamp: TimeInterval = 0

    var hasS0S1Packet: Bool {
        RTMPHandshake.sigSize + 1 < inputBuffer.count
    }

    var hasS2Packet: Bool {
        RTMPHandshake.sigSize == inputBuffer.count
    }

    private var inputBuffer: Data = .init()

    var c0c1packet: Data {
        let packet = ByteArray()
            .writeUInt8(RTMPHandshake.protocolVersion)
            .writeInt32(Int32(timestamp))
            .writeBytes(Data([0x00, 0x00, 0x00, 0x00]))
        for _ in 0..<RTMPHandshake.sigSize - 8 {
            packet.writeUInt8(UInt8.random(in: 0...UInt8.max))
        }
        return packet.data
    }

    func c2packet() -> Data {
        defer {
            inputBuffer.removeSubrange(0...Self.sigSize)
        }
        return ByteArray()
            .writeBytes(inputBuffer.subdata(in: 1..<5))
            .writeInt32(Int32(Date().timeIntervalSince1970 - timestamp))
            .writeBytes(inputBuffer.subdata(in: 9..<RTMPHandshake.sigSize + 1))
            .data
    }

    func put(_ data: Data) {
        inputBuffer.append(data)
    }

    func clear() {
        inputBuffer = .init()
        timestamp = 0
    }
}
