import Foundation
import XCTest

@testable import HaishinKit

final class ProgramSpecificTests: XCTestCase {

    static let dataForPAT: Data = .init([0, 0, 176, 13, 0, 1, 193, 0, 0, 0, 1, 240, 0, 42, 177, 4, 178])
    static let dataForPMT: Data = .init([0, 2, 176, 29, 0, 1, 193, 0, 0, 225, 0, 240, 0, 27, 225, 0, 240, 0, 15, 225, 1, 240, 6, 10, 4, 117, 110, 100, 0, 8, 125, 232, 119])

    func testPAT() {
        let pat = ProgramAssociationSpecific(ProgramSpecificTests.dataForPAT)!
        XCTAssertEqual(pat.programs, [1: 4096])
        XCTAssertEqual(pat.data, ProgramSpecificTests.dataForPAT)
    }

    func testPMT() {
        let pmt = ProgramMapSpecific(ProgramSpecificTests.dataForPMT)!
        XCTAssertEqual(pmt.data, ProgramSpecificTests.dataForPMT)
    }
}
