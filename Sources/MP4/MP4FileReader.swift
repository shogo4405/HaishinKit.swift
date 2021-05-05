import Foundation

final class MP4FileReader: MP4ReaderConvertible {
    var fileType: MP4FileTypeBox {
        root.getBoxes(by: .ftyp).first ?? MP4FileTypeBox()
    }
    var tracks: [MP4TrackReader] = []

    private var root = MP4Box()
    private let fileHandle: FileHandle

    init(forReadingFrom url: URL) throws {
        fileHandle = try FileHandle(forReadingFrom: url)
    }

    func execute() -> Self {
        do {
            var currentOffset = root.offset
            let length = fileHandle.seekToEndOfFile()
            root.children.removeAll()
            repeat {
                fileHandle.seek(toFileOffset: currentOffset)
                let buffer = ByteArray(data: fileHandle.readData(ofLength: 8))
                let size = try buffer.readUInt32()
                _ = try buffer.readUTF8Bytes(4)
                fileHandle.seek(toFileOffset: currentOffset)
                var child = MP4Box()
                child.data = fileHandle.readData(ofLength: Int(size))
                root.children.append(child)
                currentOffset += UInt64(size)
            } while currentOffset < length
        } catch {
            logger.error(error)
        }
        return self
    }

    func getBoxes<T: MP4BoxConvertible>(by name: MP4Box.Name<T>) -> [T] {
        return root.getBoxes(by: name)
    }
}

extension MP4FileReader: CustomDebugStringConvertible {
    var debugDescription: String {
        return root.debugDescription
    }
}

extension MP4FileReader: CustomXmlStringConvertible {
    var xmlString: String {
        return root.xmlString
    }
}
