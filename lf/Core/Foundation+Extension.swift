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
        
       return NSURLComponents(string: absoluteString)?.queryItems?.reduce([String: AnyObject]()) { (result, item) in
        
            var result = result
            result[item.name] = item.value
        
            return result
        
        } ?? [:]
        
    }
}
