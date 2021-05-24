import Foundation

struct ProfileLevelIndicationIndexDescriptor: BaseDescriptor {
    static let tag: UInt8 = 0x14
    // MARK: BaseDescriptor
    let tag: UInt8 = Self.tag
    var size: UInt32 = 0
    // MARK: ProfileLevelIndicationIndexDescriptor
    var profileLevelIndicationIndex: UInt8 = 0
}

extension ProfileLevelIndicationIndexDescriptor: DataConvertible {
    // MARK: DataConvertible
    var data: Data {
        get {
            let buffer = ByteArray()
                .writeUInt8(tag)
                .writeUInt32(0)
                .writeUInt8(profileLevelIndicationIndex)
            writeSize(buffer)
            return buffer.data
        }
        set {
            do {
                let buffer = ByteArray(data: newValue)
                _ = try buffer.readUInt8()
                size = try readSize(buffer)
                profileLevelIndicationIndex = try buffer.readUInt8()
            } catch {
                logger.error(error)
            }
        }
    }
}
