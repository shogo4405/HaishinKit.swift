import Foundation

final class RTMPHandshake {
    static let sigSize:Int = 1536
    static let protocolVersion:UInt8 = 3

    var timestamp:TimeInterval = 0

    var c0c1packet:[UInt8] {
        let packet:ByteArray = ByteArray()
            .writeUInt8(RTMPHandshake.protocolVersion)
            .writeInt32(Int32(timestamp))
            .writeBytes([0x00, 0x00, 0x00, 0x00])
        for _ in 0..<RTMPHandshake.sigSize - 8 {
            packet.writeUInt8(UInt8(arc4random_uniform(0xff)))
        }
        return packet.bytes
    }

    func c2packet(_ s0s1packet:[UInt8]) -> [UInt8] {
        let packet:ByteArray = ByteArray()
            .writeBytes(Array<UInt8>(s0s1packet[1...4]))
            .writeInt32(Int32(Date().timeIntervalSince1970 - timestamp))
            .writeBytes(Array<UInt8>(s0s1packet[9...RTMPHandshake.sigSize]))
        return packet.bytes
    }

    func clear() {
        timestamp = 0
    }
}
