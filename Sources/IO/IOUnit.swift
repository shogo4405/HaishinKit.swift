import AVFAudio
import Foundation

protocol IOUnit {
    var lockQueue: DispatchQueue { get }
    var mixer: IOMixer? { get }
}
