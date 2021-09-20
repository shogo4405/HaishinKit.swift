import Foundation
import XCTest

@testable import HaishinKit

final class MP4FileReaderTests2: XCTestCase {
    func testMP4FileTypeBox() {
        let file = makeFMP4File()
        let styp = file.getBoxes(by: .styp).first
        XCTAssertEqual(styp?.majorBrand, MP4Util.uint32("msdh"))
        XCTAssertEqual(styp?.minorVersion, 0)
        XCTAssertEqual(styp?.compatibleBrands[0], MP4Util.uint32("msdh"))
        XCTAssertEqual(styp?.compatibleBrands[1], MP4Util.uint32("msix"))

        let sidx = file.getBoxes(by: .sidx)
        XCTAssertEqual(sidx[0].referenceID, 1)
        XCTAssertEqual(sidx[0].timescale, 15360)
        XCTAssertEqual(sidx[0].earliestPresentationTime, 0)
        XCTAssertEqual(sidx[0].firstOffset, 52)
        XCTAssertEqual(sidx[0].references[0].type, false)
        XCTAssertEqual(sidx[0].references[0].size, 530176)
        XCTAssertEqual(sidx[0].references[0].subsegmentDuration, 92160)
        XCTAssertEqual(sidx[0].references[0].startsWithSap, true)
        XCTAssertEqual(sidx[0].references[0].sapType, 0)
        XCTAssertEqual(sidx[0].references[0].sapDeltaTime, 0)
        XCTAssertEqual(sidx[1].referenceID, 2)
        XCTAssertEqual(sidx[1].timescale, 48000)
        XCTAssertEqual(sidx[1].earliestPresentationTime, 0)
        XCTAssertEqual(sidx[1].firstOffset, 0)

        let mfhd = file.getBoxes(by: .mfhd)
        XCTAssertEqual(mfhd[0].sequenceNumber, 1)

        let tfhd = file.getBoxes(by: .tfhd)
        XCTAssertEqual(tfhd[0].flags, 131128)
        XCTAssertEqual(tfhd[0].trackId, 1)
        XCTAssertEqual(tfhd[0].baseDataOffset, nil)
        XCTAssertEqual(tfhd[0].sampleDescriptionIndex, nil)
        XCTAssertEqual(tfhd[0].defaultSampleDuration, 1024)
        XCTAssertEqual(tfhd[0].defaultSampleSize, 22696)
        XCTAssertEqual(tfhd[0].defaultSampleFlags, 16842752)

        let tfdt = file.getBoxes(by: .tfdt)
        XCTAssertEqual(tfdt[0].version, 1)
        XCTAssertEqual(tfdt[0].baseMediaDecodeTime, 0)
        XCTAssertEqual(tfdt[1].version, 1)
        XCTAssertEqual(tfdt[1].baseMediaDecodeTime, 0)
        
        let _ = file.getBoxes(by: .trun)
    }

    private func makeInitMP4File() -> MP4FileReader {
        let bundle = Bundle(for: type(of: self))
        let url = URL(fileURLWithPath: bundle.path(forResource: "SampleVideo_360x240_5mb@m4v/init", ofType: "mp4")!)
        return try! MP4FileReader(forReadingFrom: url).execute()
    }

    private func makeFMP4File() -> MP4FileReader {
        let bundle = Bundle(for: type(of: self))
        let url = URL(fileURLWithPath: bundle.path(forResource: "SampleVideo_360x240_5mb@m4v/0", ofType: "m4s")!)
        return try! MP4FileReader(forReadingFrom: url).execute()
    }
}

