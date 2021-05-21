import Foundation

protocol MP4FullBox: MP4BoxConvertible {
    var version: UInt8 { get }
    var flags: UInt32 { get }
}
