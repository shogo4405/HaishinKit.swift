import AVFoundation
import Foundation

protocol MP4FragmentedWriterDelegate: AnyObject {
    func writer(_ writer: MP4FragmentedWriter, didSegmentChanged segment: MP4Box)
}

final class MP4FragmentedWriter: MP4WriterConvertible {
    private var segment = MP4Box()
    private(set) var mapping = MP4Box()

    private var audio = MP4FragmentedTrafWriter()
    private var video = MP4FragmentedTrafWriter()

    weak var delegate: MP4FragmentedWriterDelegate?
}

extension MP4FragmentedWriter: AudioCodecDelegate {
    // MARK: AudioCodecDelegate
    func audioCodec(_ codec: AudioCodec, didSet formatDescription: CMFormatDescription?) {
    }

    func audioCodec(_ codec: AudioCodec, didOutput sample: UnsafeMutableAudioBufferListPointer, presentationTimeStamp: CMTime) {
    }
}

final class MP4FragmentedTrafWriter {
    private var tkhd = MP4TrackFragmentHeaderBox()
    private var trun = MP4TrackRunBox()
    private var tfdt = MP4TrackRunBox()
}
