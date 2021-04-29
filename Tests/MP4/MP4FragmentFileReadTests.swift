import Foundation
import XCTest

@testable import HaishinKit

final class MP4FragmentFileReadTests: XCTestCase {
    func testMP4FileTypeBox() {
        let file = makeMP4File()
        let ftyp: MP4FileTypeBox? = try? file.getBoxes(by: .ftyp).first
        XCTAssertEqual(ftyp?.minorVersion, 512)
    }

    func testMP4SampleSizeBox() {
        let file = makeMP4File()
        let stsz: [MP4SampleSizeBox]? = try? file.getBoxes(by: .stsz)
        XCTAssertEqual(stsz?.first?.entries[0], 22696)
        XCTAssertEqual(stsz?.first?.entries[1], 807)
        XCTAssertEqual(stsz?.first?.entries[2], 660)
        XCTAssertEqual(stsz?.last?.entries[0], 1011)
        XCTAssertEqual(stsz?.last?.entries[1], 1026)
        XCTAssertEqual(stsz?.last?.entries[2], 1030)
    }

    private func makeMP4File() -> MP4FileHandle {
        let bundle = Bundle(for: type(of: self))
        let url = URL(fileURLWithPath: bundle.path(forResource: "SampleVideo_360x240_5mb", ofType: "mp4")!)
        var file = try! MP4FileHandle(forReadingFrom: url)
        try! file.load()
        return file
    }
}

