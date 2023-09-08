import Foundation

protocol Codec {
    associatedtype Buffer

    var inputBuffer: Buffer { get }
    var outputBuffer: Buffer { get }

    func releaseOutputBuffer(_ buffer: Buffer)
}
