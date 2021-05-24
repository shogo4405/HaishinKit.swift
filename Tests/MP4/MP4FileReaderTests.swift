import Foundation
import XCTest

@testable import HaishinKit

final class MP4FileReaderTests: XCTestCase {
    func testMP4FileTypeBox() {
        let file = makeMP4File()
        let ftyp: MP4FileTypeBox? = file.getBoxes(by: .ftyp).first
        XCTAssertEqual(ftyp?.minorVersion, 512)
    }

    func testMP4MovieHeaderBox() {
        let file = makeMP4File()
        let mvhd = file.getBoxes(by: .mvhd).first
        XCTAssertEqual(mvhd?.creationTime, 2082844800)
        XCTAssertEqual(mvhd?.modificationTime, 3488636519)
        XCTAssertEqual(mvhd?.timeScale, 1000)
        XCTAssertEqual(mvhd?.duration, 64896)
        XCTAssertEqual(mvhd?.rate, 65536)
        XCTAssertEqual(mvhd?.volume, MP4MovieHeaderBox.volume)
        XCTAssertEqual(mvhd?.matrix, [65536, 0, 0, 0, 65536, 0, 0, 0, 1073741824])
        XCTAssertEqual(mvhd?.nextTrackID, 3)
    }

    func testMP4SampleSizeBox() {
        let file = makeMP4File()
        let stsz: [MP4SampleSizeBox]? = file.getBoxes(by: .stsz)
        XCTAssertEqual(stsz?.first?.entries[0], 22696)
        XCTAssertEqual(stsz?.first?.entries[1], 807)
        XCTAssertEqual(stsz?.first?.entries[2], 660)
        XCTAssertEqual(stsz?.last?.entries[0], 1011)
        XCTAssertEqual(stsz?.last?.entries[1], 1026)
        XCTAssertEqual(stsz?.last?.entries[2], 1030)
    }

    func testMP4ChunkOffsetBox() {
        let file = makeMP4File()
        let stco = file.getBoxes(by: .stco).first
        XCTAssertEqual(stco?.entries[0], 1059)
        XCTAssertEqual(stco?.entries[1], 26801)
    }

    func testMP4EditListBox() {
        let file = makeMP4File()
        let elst = file.getBoxes(by: .elst).first
        XCTAssertEqual(elst?.entries[0].mediaRateFraction, 0)
        XCTAssertEqual(elst?.entries[0].mediaRateInteger, 1)
        XCTAssertEqual(elst?.entries[0].mediaTime, 0)
        XCTAssertEqual(elst?.entries[0].segmentDuration, 64867)
    }
    
    func testMP4SampleToChunkBox() {
        let file = makeMP4File()
        let stsc = file.getBoxes(by: .stsc).first
        XCTAssertEqual(stsc?.entries[0].firstChunk, 1)
        XCTAssertEqual(stsc?.entries[0].samplesPerChunk, 1)
        XCTAssertEqual(stsc?.entries[0].sampleDescriptionIndex, 1)
    }

    func testMP4SyncSampleBox() {
        let file = makeMP4File()
        let stss = file.getBoxes(by: .stss).first
        XCTAssertEqual(stss?.entries[0], 1)
        XCTAssertEqual(stss?.entries[1], 127)
        XCTAssertEqual(stss?.entries[2], 196)
    }

    func testMP4MediaHeaderBox() {
        let file = makeMP4File()
        let mdhd = file.getBoxes(by: .mdhd).first
        XCTAssertEqual(mdhd?.creationTime, 2082844800)
        XCTAssertEqual(mdhd?.modificationTime, 2082844800)
        XCTAssertEqual(mdhd?.timeScale, 15360)
        XCTAssertEqual(mdhd?.duration, 996352)
        XCTAssertEqual(mdhd?.language, [21, 14, 4])
    }

    func testMP4AudioSampleEntryBox() {
        let file = makeMP4File()
        let mp4a = file.getBoxes(by: .stsd).last?.getBoxes(by: .mp4a).first

        XCTAssertEqual(mp4a?.dataReferenceIndex, 1)
        XCTAssertEqual(mp4a?.channelCount, 2)
        XCTAssertEqual(mp4a?.sampleSize, 16)
        XCTAssertEqual(mp4a?.sampleRate, 48000)

        let esds = mp4a?.getBoxes(by: .esds).first
        XCTAssertEqual(esds?.flags, 0)
        XCTAssertEqual(esds?.version, 0)

        // ESDescriptor
        XCTAssertEqual(esds?.descriptor.tag, 3)
        XCTAssertEqual(esds?.descriptor.ES_ID, 2)

        // DecoderConfigDescriptor
        XCTAssertEqual(esds?.descriptor.decConfigDescr.tag, DecoderConfigDescriptor.tag)
        XCTAssertEqual(esds?.descriptor.decConfigDescr.objectTypeIndication, 64)
        XCTAssertEqual(esds?.descriptor.decConfigDescr.streamType, 5)
        XCTAssertEqual(esds?.descriptor.decConfigDescr.avgBitrate, 383586)
        XCTAssertEqual(esds?.descriptor.decConfigDescr.maxBitrate, 449032)

        XCTAssertEqual(esds?.descriptor.decConfigDescr.decSpecificInfo.tag, DecoderSpecificInfo.tag)
        XCTAssertEqual(esds?.descriptor.decConfigDescr.decSpecificInfo.size, 2)
        
        XCTAssertEqual(esds?.descriptor.decConfigDescr.profileLevelIndicationIndexDescriptor.tag, ProfileLevelIndicationIndexDescriptor.tag)
        XCTAssertEqual(esds?.descriptor.decConfigDescr.profileLevelIndicationIndexDescriptor.profileLevelIndicationIndex, 2)

        XCTAssertEqual(esds?.descriptor.slConfigDescr.tag, 6)
        XCTAssertEqual(esds?.descriptor.slConfigDescr.predefined, 2)
    }

    private func makeMP4File() -> MP4FileReader {
        let bundle = Bundle(for: type(of: self))
        let url = URL(fileURLWithPath: bundle.path(forResource: "SampleVideo_360x240_5mb", ofType: "mp4")!)
        return try! MP4FileReader(forReadingFrom: url).execute()
    }
}

