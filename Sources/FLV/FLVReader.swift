import AVFoundation

open class FLVReader {
    public static let header = Data([0x46, 0x4C, 0x56, 1])
    static let headerSize: Int = 11

    public let url: URL
    private var currentOffSet: UInt64 = 0
    private var fileHandle: FileHandle?

    public init(url: URL) {
        do {
            self.url = url
            fileHandle = try FileHandle(forReadingFrom: url)
            fileHandle?.seek(toFileOffset: 13)
            currentOffSet = 13
        } catch let error as NSError {
            logger.error("\(error)")
        }
    }

    public func getData(_ tag: FLVTag) -> Data? {
        fileHandle?.seek(toFileOffset: tag.offset)
        return fileHandle?.readData(ofLength: Int(UInt64(tag.dataSize)))
    }
}

extension FLVReader: IteratorProtocol {
    // MARK: IteratorProtocol
    public func next() -> FLVTag? {
        guard let fileHandle: FileHandle = fileHandle else {
            return nil
        }
        var tag: FLVTag!
        fileHandle.seek(toFileOffset: currentOffSet)
        let data: Data = fileHandle.readData(ofLength: FLVReader.headerSize)
        guard !data.isEmpty else {
            return nil
        }
        switch data[0] {
        case 8:
            tag = FLVAudioTag(data: data)
        case 9:
            tag = FLVVideoTag(data: data)
        case 18:
            tag = FLVDataTag(data: data)
        default:
            return nil
        }
        tag.readData(fileHandle)
        tag.offset = currentOffSet + UInt64(FLVReader.headerSize)
        currentOffSet += UInt64(FLVReader.headerSize) + UInt64(tag.dataSize) + 4
        return tag
    }
}
