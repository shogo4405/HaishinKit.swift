import Foundation

final class RTMPAuthenticator {
    enum Error: Swift.Error {
        case noCredential
        case failedToAuth(description: String)
    }

    private static func makeSanJoseAuthCommand(_ url: URL, description: String) -> String {
        var command: String = url.absoluteString

        guard let index = description.firstIndex(of: "?") else {
            return command
        }

        let query = String(description[description.index(index, offsetBy: 1)...])
        let challenge = String(format: "%08x", UInt32.random(in: 0...UInt32.max))
        let dictionary = URL(string: "http://localhost?" + query)!.dictionaryFromQuery()

        var response = MD5.base64("\(url.user!)\(dictionary["salt"]!)\(url.password!)")
        if let opaque = dictionary["opaque"] {
            command += "&opaque=\(opaque)"
            response += opaque
        } else if let challenge: String = dictionary["challenge"] {
            response += challenge
        }

        response = MD5.base64("\(response)\(challenge)")
        command += "&challenge=\(challenge)&response=\(response)"

        return command
    }

    func makeCommand(_ command: String, status: RTMPStatus) -> Result<String, Error> {
        switch true {
        case status.description.contains("reason=needauth"):
            guard
                let uri = URL(string: command) else {
                return .failure(Error.noCredential)
            }
            let command = Self.makeSanJoseAuthCommand(uri, description: status.description)
            return .success(command)
        case status.description.contains("authmod=adobe"):
            guard
                let uri = URL(string: command),
                let user = uri.user, uri.password != nil else {
                return .failure(Error.noCredential)
            }
            let query = uri.query ?? ""
            let command = uri.absoluteString + (query.isEmpty ? "?" : "&") + "authmod=adobe&user=\(user)"
            return .success(command)
        default:
            return .failure(Error.failedToAuth(description: status.description))
        }
    }
}
