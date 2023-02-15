import Foundation
import XCTest

@testable import HaishinKit

final class TSTests: XCTestCase {
    static let dataWithMetadata: Data = .init([71, 64, 17, 16, 0, 66, 240, 37, 0, 1, 193, 0, 0, 0, 1, 255, 0, 1, 252, 128, 20, 72, 18, 1, 6, 70, 70, 109, 112, 101, 103, 9, 83, 101, 114, 118, 105, 99, 101, 48, 49, 167, 121, 160, 3, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255])

    func testTSPacket() {
        let packetWithMetadata = TSPacket(data: TSTests.dataWithMetadata)!
        XCTAssertEqual(packetWithMetadata.syncByte, TSPacket.defaultSyncByte)
        XCTAssertEqual(packetWithMetadata.PID, 17)
        XCTAssertEqual(packetWithMetadata.data, TSTests.dataWithMetadata)
    }

    func testTSReader() {
        do {
            let bundle: Bundle = .init(for: type(of: self))
            let url: URL = .init(fileURLWithPath: bundle.path(forResource: "SampleVideo_360x240_5mb/000", ofType: "ts")!)
            let reader: TSReader = try TSReader(url: url)
            reader.read()
            XCTAssertEqual(reader.numberOfPackets, 5984)
        } catch {
        }
    }

    func testTSProgramClockReference() {
        let data = Data([0, 1, 66, 68, 126, 0])
        let (b, e) = TSProgramClockReference.decode(data)
        XCTAssertEqual(data, TSProgramClockReference.encode(b, e))
    }

    func testTSTimestamp() {
        XCTAssertEqual(0, TSTimestamp.decode(Data([49, 0, 1, 0, 1])))
        XCTAssertEqual(0, TSTimestamp.decode(Data([17, 0, 1, 0, 1])))
        XCTAssertEqual(Data([49, 0, 1, 0, 1]), TSTimestamp.encode(0, TSTimestamp.PTSDTSMask))
        XCTAssertEqual(Data([17, 0, 1, 0, 1]), TSTimestamp.encode(0, TSTimestamp.PTSMask))
    }
}
