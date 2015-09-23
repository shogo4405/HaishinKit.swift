import Foundation

class HTTPRequest:NSObject {

    enum Header:String {
        case ContentType = "Content-Type"
        case ContentLength = "Content-Length"
        case UserAgent = "User-Agent"
    }

    var uri:String = ""
    var method:String = ""
    var headers:[String:String] = [:]
    var content:[UInt8] = []

    override var description:String {
        var description:String = "HTTPRequest{"
        description += "uri=\(uri),"
        description += "method=\(method),"
        description += "headers=\(headers),"
        description += "content=\(content)"
        description += "}"
        return description
    }

    private var _bytes:[UInt8] = []
    var bytes:[UInt8] {
        set {
            _bytes = newValue

            let body:String = String(bytes: bytes, encoding: NSASCIIStringEncoding)!
            var lines:[String] = body.componentsSeparatedByString("\r\n")
            let first:[String] = lines.removeAtIndex(0).componentsSeparatedByString(" ")

            method = first[0]
            uri = first[1]
            for line in lines {
                if (line == "") {
                    break
                }
                let pairs:[String] = line.componentsSeparatedByString(": ")
                headers[pairs[0]] = pairs[1]
            }

            if let length:Int = Int(headers[HTTPRequest.Header.ContentLength.rawValue]!) {
                content = Array(newValue[bytes.count - length..<bytes.count])
            }
        }
        get {
            return _bytes
        }
    }
}
