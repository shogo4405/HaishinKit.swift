import Foundation
import XCTest

@testable import HaishinKit

final class PacketizedElementaryStreamTests: XCTestCase {

    static let dataWithVideo: Data = .init([0, 0, 1, 224, 0, 0, 128, 128, 5, 33, 0, 7, 216, 97, 0, 0, 0, 1, 9, 240, 0, 0, 0, 1, 103, 77, 64, 13, 218, 5, 7, 236, 4, 64, 0, 0, 3, 0, 64, 0, 0, 7, 131, 197, 10, 168, 0, 0, 0, 1, 104, 239, 60, 128, 0, 0, 0, 1, 101, 136, 130, 1, 15, 250, 120, 30, 255, 244, 55, 157, 215, 115, 255, 239, 112, 39, 83, 211, 17, 103, 152, 229, 241, 131, 49, 7, 123, 10, 145, 184, 0, 0, 3, 3, 133, 122, 49, 20, 214, 115, 51, 202, 59, 43, 204, 79, 27, 229, 101, 135, 60, 234, 243, 78, 210, 98, 30, 252, 36, 38, 20, 202, 41, 121, 70, 45, 15, 54, 125, 153, 199, 236, 90, 142, 247, 27, 202, 17, 205, 77, 133, 21, 189, 212, 159, 87, 222, 100, 53, 75, 211, 139, 219, 83, 89, 59, 199, 242, 182, 18, 245, 72, 70, 50, 230, 58, 82, 122, 179, 121, 243, 232, 107, 206, 157, 13])

    func testPES() {
        let pes = PacketizedElementaryStream(PacketizedElementaryStreamTests.dataWithVideo)!
        XCTAssertEqual(pes.payload, PacketizedElementaryStreamTests.dataWithVideo)
    }
}
