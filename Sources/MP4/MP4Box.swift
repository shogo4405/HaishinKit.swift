import Foundation

struct MP4Box: MP4BoxConvertible {
    static let containers: Set<String> = [
        "cmov",
        "ctts",
        "edts",
        "iods",
        "junk",
        "mdia",
        "minf",
        "moov",
        "pict",
        "pnot",
        "rmda",
        "rmra",
        "skip",
        "stbl",
        "trak",
        "uuid",
        "wide",
        "moof",
        "traf"
    ]

    class Names {
    }

    final class Name<T: MP4BoxConvertible>: Names, Hashable, RawRepresentable {
        let rawValue: String
        // swiftlint:disable nesting
        typealias RawValue = String

        init(rawValue: String) {
            self.rawValue = rawValue
        }
    }

    var size: UInt32 = 0
    var type: String = ""
    var offset: UInt64 = 0
    var children: [MP4BoxConvertible] = []
    private var _data = Data()
}

extension MP4Box: DataConvertible {
    var data: Data {
        get {
            _data
        }
        set {
            do {
                _data = newValue
                let buffer = ByteArray(data: newValue)
                size = try buffer.readUInt32()
                type = try buffer.readUTF8Bytes(4)
                if Self.containers.contains(type) {
                    children.removeAll()
                    while 0 < buffer.bytesAvailable {
                        let size = try buffer.readInt32()
                        _ = try buffer.readBytes(4)
                        buffer.position -= 8
                        var child = MP4Box()
                        child.data = try buffer.readBytes(Int(size))
                        children.append(child)
                    }
                }
            } catch {
                logger.error(error)
            }
        }
    }
}

extension MP4Box.Names {
    static let trak = MP4Box.Name<MP4Box>(rawValue: "trak")
}

extension MP4Box: CustomDebugStringConvertible {
    // MARK: CustomDebugStringConvertible
    var debugDescription: String {
        Mirror(reflecting: self).debugDescription
    }
}
