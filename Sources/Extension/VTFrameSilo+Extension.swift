import Foundation
import VideoToolbox

extension VTFrameSilo {
    func addSampleBuffer(_ sampleBuffer: CMSampleBuffer) throws {
        let status = VTFrameSiloAddSampleBuffer(self, sampleBuffer: sampleBuffer)
        guard status == noErr else {
            throw OSError.invoke(function: #function, status: status)
        }
    }

    func forEachSampleBuffer(_ range: CMTimeRange, handler: (CMSampleBuffer) -> OSStatus) throws {
        let status = VTFrameSiloCallBlockForEachSampleBuffer(self, in: range, handler: handler)
        guard status == noErr else {
            throw OSError.invoke(function: #function, status: status)
        }
    }
}
