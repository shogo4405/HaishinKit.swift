import Foundation

struct MP4SegmentFile {
    struct Builder {
        private var styp: MP4FileTypeBox?
        private var sidx: [MP4Box] = []
        private var moof: MP4Box?
        private var mdat: [MP4Box] = []

        mutating func setSegmentTypeBox(_ styp: MP4FileTypeBox?) -> Self {
            self.styp = styp
            return self
        }

        mutating func addSegmentIndexBox(_ sidx: MP4Box?) -> Self {
            guard let sidx = sidx else {
                return self
            }
            self.sidx.append(sidx)
            return self
        }

        mutating func setMovieFragmentBox(_ moof: MP4Box?) -> Self {
            guard let moof = moof else {
                return self
            }
            self.moof = moof
            return self
        }

        mutating func addMediaDataContainer(_ mdat: MP4Box?) -> Self {
            guard let mdat = mdat else {
                return self
            }
            self.mdat.append(mdat)
            return self
        }

        func build() -> MP4Box {
            var box = MP4Box()
            if let styp = styp {
                box.children.append(styp)
            }
            for s in sidx {
                box.children.append(s)
            }
            if let moof = moof {
                box.children.append(moof)
            }
            for m in mdat {
                box.children.append(m)
            }
            return box
        }
    }
}
