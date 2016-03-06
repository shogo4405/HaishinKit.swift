import Foundation
import AVFoundation

protocol IEffect: class {
    func execute(sampleBuffer: CMSampleBuffer!)
}
