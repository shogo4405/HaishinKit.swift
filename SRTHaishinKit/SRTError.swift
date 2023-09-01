import Foundation

enum SRTError: Error {
    case illegalState(message: String)
    case invalidArgument(message: String)
}
