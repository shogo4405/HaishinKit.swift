import Foundation

struct MP4TrackFragmentBox {
    struct Builder {
        private var tkhd: MP4TrackFragmentHeaderBox?
        private var trun: MP4TrackRunBox?
        private var tfdt: MP4TrackFragmentBaseMediaDecodeTimeBox?

        mutating func setTrackFragmentHeaderBox(_ tkhd: MP4TrackFragmentHeaderBox?) -> Self {
            self.tkhd = tkhd
            return self
        }

        mutating func setTrackRunBox(_ trun: MP4TrackRunBox?) -> Self {
            self.trun = trun
            return self
        }

        mutating func setTrackFragmentBaseMediaDecodeTimeBox(_ tfdt: MP4TrackFragmentBaseMediaDecodeTimeBox?) -> Self {
            self.tfdt = tfdt
            return self
        }

        func build() -> MP4Box {
            return MP4Box()
        }
    }
}
