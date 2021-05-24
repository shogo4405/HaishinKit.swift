import Foundation

protocol MP4SampleEntry: MP4BoxConvertible {
    var dataReferenceIndex: UInt16 { get }
}
