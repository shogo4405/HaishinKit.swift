import AVFAudio
import Foundation

protocol CaptureUnit {
    var lockQueue: DispatchQueue { get }
}
