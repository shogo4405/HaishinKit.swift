import AVFoundation

final class MP4Reader: MP4ReaderConvertible {
    let fileType: MP4FileTypeBox
    let tracks: [MP4TrackReader]

    init(fileType: MP4FileTypeBox, tracks: [MP4TrackReader]) {
        self.fileType = fileType
        self.tracks = tracks
    }
}

final class MP4TrackReader {
    struct MP4SampleIterator: IteratorProtocol {
        // swiftlint:disable nesting
        typealias Element = UInt8

        private var cursor: Int = 0
        private let reader: MP4TrackReader

        init(reader: MP4TrackReader) {
            self.reader = reader
        }

        mutating func next() -> Element? {
            return nil
        }
    }

    func makeIterator() -> MP4SampleIterator {
        return MP4SampleIterator(reader: self)
    }
}
