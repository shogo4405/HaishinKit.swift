import Foundation
import AVFoundation

final class FLVReader {
    static let header:Data = Data([0x46, 0x4C, 0x56, 1])

    private(set) var url:URL
    private(set) var hasAudio:Bool = false
    private(set) var hasVideo:Bool = false
    private var currentOffSet:UInt64 = 0
    private var fileHandle:FileHandle? = nil

    init(url:URL) {
        do {
            self.url = url
            fileHandle = try FileHandle(forReadingFrom: url)
            fileHandle?.seek(toFileOffset: 13)
            currentOffSet = 13
        } catch let error as NSError {
            logger.error("\(error)")
        }
    }
}

extension FLVReader: IteratorProtocol {
    func next() -> FLVTag? {
        guard let fileHandle:FileHandle = fileHandle else {
            return nil
        }
        let data:Data = fileHandle.readData(ofLength: FLVTag.headerSize)
        guard let tag:FLVTag = FLVTag(data: data) else {
            return nil
        }
        currentOffSet += UInt64(FLVTag.headerSize) + UInt64(tag.dataSize) + 4
        fileHandle.seek(toFileOffset: currentOffSet)
        return tag
    }
}
