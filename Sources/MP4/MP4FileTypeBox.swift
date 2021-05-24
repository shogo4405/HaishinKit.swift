import Foundation

struct MP4FileTypeBox: MP4BoxConvertible {
    // MARK: MP4BoxConvertible
    var size: UInt32 = 0
    var type: String = ""
    var offset: UInt64 = 0
    var children: [MP4BoxConvertible] = []
    // MARK: MP4MediaHeaderBox
    var majorBrand: UInt32 = 0
    var minorVersion: UInt32 = 0
    var compatibleBrands: [UInt32] = []
}

extension MP4FileTypeBox: DataConvertible {
    var data: Data {
        get {
            let buffer = ByteArray()
                .writeUInt32(size)
                .writeUTF8Bytes(type)
                .writeUInt32(majorBrand)
                .writeUInt32(minorVersion)
            for brand in compatibleBrands {
                buffer.writeUInt32(brand)
            }
            return buffer.data
        }
        set {
            do {
                let buffer = ByteArray(data: newValue)
                size = try buffer.readUInt32()
                type = try buffer.readUTF8Bytes(4)
                majorBrand = try buffer.readUInt32()
                minorVersion = try buffer.readUInt32()
                compatibleBrands.removeAll()
                while 0 < buffer.bytesAvailable {
                    compatibleBrands.append(try buffer.readUInt32())
                }
            } catch {
                logger.error(error)
            }
        }
    }
}

extension MP4Box.Names {
    static let styp = MP4Box.Name<MP4FileTypeBox>(rawValue: "styp")
    static let ftyp = MP4Box.Name<MP4FileTypeBox>(rawValue: "ftyp")
}
