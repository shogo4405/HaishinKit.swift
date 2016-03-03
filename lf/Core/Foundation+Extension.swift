import Foundation

extension NSURL {
    
    var absoluteWithoutAuthenticationString:String {
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
            return self.absoluteString
        }
        return absoluteString.stringByReplacingOccurrencesOfString("?" + query, withString: "")
    }
    
    func dictionaryFromQuery() -> [String: AnyObject] {
        var result:[String: AnyObject] = [:]
        if let comonents:NSURLComponents = NSURLComponents(string: absoluteString) {
            for (var i=0; i < comonents.queryItems?.count; ++i) {
                if let item:NSURLQueryItem = comonents.queryItems?[i] {
                    result[item.name] = item.value
                }
            }
        }
        return result
    }
}
