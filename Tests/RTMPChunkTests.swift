import Foundation
import XCTest

@testable import lf

final class RTMPChunkTests: XCTestCase {
    func testChunkTwo() {
        let bytes:[UInt8] = [130, 0, 0, 0, 0, 4, 9, 104]
        let chunk:RTMPChunk? = RTMPChunk(bytes: bytes, size: 128)
        if let chunk:RTMPChunk = chunk {
            XCTAssertEqual(chunk.type, .two)
        }
    }
}
