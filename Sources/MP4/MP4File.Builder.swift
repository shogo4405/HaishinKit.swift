import Foundation

struct MP4File {
    struct Builder {
        private var ftyp: MP4FileTypeBox?
        private var moov: MP4Box?

        mutating func setFileTypeBox(_ ftyp: MP4FileTypeBox?) -> Self {
            self.ftyp = ftyp
            return self
        }

        mutating func setMoovieBox(_ moov: MP4Box?) -> Self {
            self.moov = moov
            return self
        }

        func build() -> MP4Box {
            var box = MP4Box()
            if let ftyp = ftyp {
                box.children.append(ftyp)
            }
            if let moov = moov {
                box.children.append(moov)
            }
            return box
        }
    }
}
