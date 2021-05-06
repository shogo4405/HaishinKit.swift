import Foundation

struct MP4MovieFragmentBox {
    struct Builder {
        private var mfhd: MP4MovieFragmentHeaderBox?
        private var traf: [MP4Box] = []

        mutating func setMovieFragmentHeaderBox(_ mfhd: MP4MovieFragmentHeaderBox?) -> Self {
            self.mfhd = mfhd
            return self
        }

        mutating func addTrackFragmentBox(_ traf: MP4Box?) -> Self {
            guard let traf = traf else {
                return self
            }
            self.traf.append(traf)
            return self
        }

        func build() -> MP4Box {
            var box = MP4Box()
            if let mfhd = mfhd {
                box.children.append(mfhd)
            }
            for t in traf {
                box.children.append(t)
            }
            return box
        }
    }
}
