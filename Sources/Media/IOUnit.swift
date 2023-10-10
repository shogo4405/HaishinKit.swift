import AVFAudio
import Foundation

protocol IOUnit {
    associatedtype FormatDescription

    var mixer: IOMixer? { get set }
    var muted: Bool { get set }
    var inputFormat: FormatDescription? { get }
    var outputFormat: FormatDescription? { get }

    func append(_ sampleBuffer: CMSampleBuffer)
}

protocol IOUnitEncoding {
    func startEncoding()
    func stopEncoding()
}

protocol IOUnitDecoding {
    func startDecoding()
    func stopDecoding()
}
