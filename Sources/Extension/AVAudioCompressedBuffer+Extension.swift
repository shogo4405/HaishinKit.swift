import AVFoundation
import Foundation

extension AVAudioCompressedBuffer {
    @discardableResult
    @inline(__always)
    final func copy(_ buffer: AVAudioBuffer) -> Bool {
        guard let buffer = buffer as? AVAudioCompressedBuffer else {
            return false
        }
        if let packetDescriptions = buffer.packetDescriptions {
            self.packetDescriptions?.pointee = packetDescriptions.pointee
        }
        packetCount = buffer.packetCount
        byteLength = buffer.byteLength
        data.copyMemory(from: buffer.data, byteCount: Int(buffer.byteLength))
        return true
    }
}
