import Foundation
import Testing

@testable import HaishinKit

@Suite struct TSPacketTests {
    static let dataWithMetadata: Data = .init([71, 64, 17, 16, 0, 66, 240, 37, 0, 1, 193, 0, 0, 0, 1, 255, 0, 1, 252, 128, 20, 72, 18, 1, 6, 70, 70, 109, 112, 101, 103, 9, 83, 101, 114, 118, 105, 99, 101, 48, 49, 167, 121, 160, 3, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255])

    @Test func packet() {
        let packetWithMetadata = TSPacket(data: TSPacketTests.dataWithMetadata)!
        #expect(packetWithMetadata.syncByte == TSPacket.defaultSyncByte)
        #expect(packetWithMetadata.pid == 17)
        #expect(packetWithMetadata.data == TSPacketTests.dataWithMetadata)
    }

    @Test func programClockReference() {
        let data = Data([0, 1, 66, 68, 126, 0])
        let (b, e) = TSProgramClockReference.decode(data)
        #expect(data == TSProgramClockReference.encode(b, e))
    }

    @Test func timestamp() {
        #expect(0 == TSTimestamp.decode(Data([49, 0, 1, 0, 1])))
        #expect(0 == TSTimestamp.decode(Data([17, 0, 1, 0, 1])))
        #expect(Data([49, 0, 1, 0, 1]) == TSTimestamp.encode(0, TSTimestamp.ptsDtsMask))
        #expect(Data([17, 0, 1, 0, 1]) == TSTimestamp.encode(0, TSTimestamp.ptsMask))
    }
}
