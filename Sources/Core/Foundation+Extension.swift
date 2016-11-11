import Foundation

extension NSURL {
    var absoluteWithoutAuthenticationString:String {
        guard let absoluteString:String = absoluteString else {
            return ""
        }
        var target:String = ""
        if let user:String = user {
            target += user
        }
        if let password:String = password {
            target += ":" + password
        }
        if (target != "") {
            target += "@"
        }
        return absoluteString.stringByReplacingOccurrencesOfString(target, withString: "")
    }

    var absoluteWithoutQueryString:String {
        guard let query:String = self.query else {
            return self.absoluteString ?? ""
        }
        return (absoluteString ?? "").stringByReplacingOccurrencesOfString("?" + query, withString: "")
    }

    func dictionaryFromQuery() -> [String: AnyObject] {
        var result:[String: AnyObject] = [:]
        guard
            let absoluteString:String = absoluteString,
            let comonents:NSURLComponents = NSURLComponents(string: absoluteString),
            let queryItems = comonents.queryItems else {
            return result
        }
        for i in 0..<queryItems.count {
            if let item:NSURLQueryItem = queryItems[i] {
                result[item.name] = item.value
            }
        }
        return result
    }
}
