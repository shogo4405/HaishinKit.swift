import Foundation

enum OSError: Swift.Error {
    case invoke(function: String, status: OSStatus)
}
