import Foundation

protocol MP4ReaderConvertible: AnyObject {
    var fileType: MP4FileTypeBox { get }
    var tracks: [MP4TrackReader] { get }

    func execute() -> Self
}

extension MP4ReaderConvertible {
    func execute() -> Self {
        return self
    }
}
