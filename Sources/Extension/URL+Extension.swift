import Foundation

extension URL {
    var absoluteWithoutAuthenticationString: String {
        var target: String = ""
        if let user = user {
            target += user
        }
        if let password: String = password {
            target += ": " + password
        }
        if target != "" {
            target += "@"
        }
        return absoluteString.replacingOccurrences(of: target, with: "")
    }

    var absoluteWithoutQueryString: String {
        guard let query: String = self.query else {
            return self.absoluteString
        }
        return absoluteString.replacingOccurrences(of: "?" + query, with: "")
    }

    func dictionaryFromQuery() -> [String: String] {
        var result: [String: String] = [:]
        guard let query = URLComponents(string: absoluteString)?.queryItems else {
            return result
        }
        for item in query {
            if let value: String = item.value {
                result[item.name] = value
            }
        }
        return result
    }
}
