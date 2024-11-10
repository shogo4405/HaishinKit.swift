import Foundation

protocol Codec {
    associatedtype Buffer

    var outputBuffer: Buffer { get }

    func releaseOutputBuffer(_ buffer: Buffer)
}
