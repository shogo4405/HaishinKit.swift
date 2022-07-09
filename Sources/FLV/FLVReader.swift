import AVFoundation

/// The FLVReader is used to read the contents of a FLV file.
public final class FLVReader {
    /// The header of a FLV.
    public static let header = Data([0x46, 0x4C, 0x56, 1])

    /// The headerSize of a FLV.
    static let headerSize: Int = 11

    /// The url of a FLV file.
    public let url: URL
    private var currentOffSet: UInt64 = 0
    private var fileHandle: FileHandle?

    /// Initializes and returns a newly allocated reader.
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

    /// Returns data by FLVTag.
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
