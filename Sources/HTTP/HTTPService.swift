import Foundation

// MARK: HTTPVersion
enum HTTPVersion: String {
    case Version10 = "HTTP/1.0"
    case Version11 = "HTTP/1.1"
}

// MARK: CustomStringConvertible
extension HTTPVersion: CustomStringConvertible {
    var description:String {
        return rawValue
    }
}

// MARK: - HTTPMethod
enum HTTPMethod: String {
    case GET     = "GET"
    case POST    = "POST"
    case PUT     = "PUT"
    case DELETE  = "DELETE"
    case HEAD    = "HEAD"
    case OPTIONS = "OPTIONS"
    case TRACE   = "TRACE"
    case CONNECT = "CONNECT"
}

// MARK: HTTPStatusCode
enum HTTPStatusCode: Int {
    case Continue                     = 100
    case SwitchingProtocols           = 101
    case OK                           = 200
    case Created                      = 201
    case Accepted                     = 202
    case NonAuthoritative             = 203
    case NoContent                    = 204
    case ResetContent                 = 205
    case PartialContent               = 206
    case MultipleChoices              = 300
    case MovedParmanently             = 301
    case Found                        = 302
    case SeeOther                     = 303
    case NotModified                  = 304
    case UseProxy                     = 305
    case TemporaryRedirect	          = 307
    case BadRequest                   = 400
    case Unauthorixed                 = 401
    case PaymentRequired              = 402
    case Forbidden                    = 403
    case NotFound                     = 404
    case MethodNotAllowed             = 405
    case NotAcceptable                = 406
    case ProxyAuthenticationRequired  = 407
    case RequestTimeOut               = 408
    case Conflict                     = 409
    case Gone                         = 410
    case LengthRequired               = 411
    case PreconditionFailed	          = 412
    case RequestEntityTooLarge        = 413
    case RequestURITooLarge           = 414
    case UnsupportedMediaType         = 415
    case RequestedRangeNotSatisfiable = 416
    case ExpectationFailed            = 417
    case InternalServerError          = 500
    case NotImplemented               = 501
    case BadGateway                   = 502
    case ServiceUnavailable           = 503
    case GatewayTimeOut               = 504
    case HTTPVersionNotSupported      = 505

    var message:String {
        switch self {
        case Continue:
            return "Continue"
        case SwitchingProtocols:
            return "Switching Protocols"
        case OK:
            return "OK"
        case Created:
            return "Created"
        case Accepted:
            return "Accepted"
        case NonAuthoritative:
            return "Non-Authoritative Information"
        case NoContent:
            return "No Content"
        case ResetContent:
            return "Reset Content"
        case PartialContent:
            return "Partial Content"
        case MultipleChoices:
            return "Multiple Choices"
        case MovedParmanently:
            return "Moved Permanently"
        case Found:
            return "Found"
        case SeeOther:
            return "See Other"
        case NotModified:
            return "Not Modified"
        case UseProxy:
            return "Use Proxy"
        case TemporaryRedirect:
            return "Temporary Redirect"
        case BadRequest:
            return "Bad Request"
        case Unauthorixed:
            return "Unauthorixed"
        case PaymentRequired:
            return "Payment Required"
        case Forbidden:
            return "Forbidden"
        case NotFound:
            return "Not Found"
        case MethodNotAllowed:
            return "Method Not Allowed"
        case NotAcceptable:
            return "Not"
        case ProxyAuthenticationRequired:
            return "Proxy Authentication Required"
        case RequestTimeOut:
            return "Request Time-out"
        case Conflict:
            return "Conflict"
        case Gone:
            return "Gone"
        case LengthRequired:
            return "Length Required"
        case PreconditionFailed:
            return "Precondition Failed"
        case RequestEntityTooLarge:
            return "Request Entity Too Large"
        case RequestURITooLarge:
            return "Request-URI Too Large"
        case UnsupportedMediaType:
            return "Unsupported Media Type"
        case RequestedRangeNotSatisfiable:
            return "Requested range not satisfiable"
        case ExpectationFailed:
            return "Expectation Failed"
        case InternalServerError:
            return "Internal Server Error"
        case NotImplemented:
            return "Not Implemented"
        case BadGateway:
            return "Bad Gateway"
        case ServiceUnavailable:
            return "Service Unavailable"
        case GatewayTimeOut:
            return "Gateway Time-out"
        case HTTPVersionNotSupported:
            return "HTTP Version not supported"
        }
    }
}

// MARK: CustomStringConvertible
extension HTTPStatusCode: CustomStringConvertible {
    var description:String {
        return "\(rawValue) \(message)"
    }
}

// MARK: -
public class HTTPService: NetService {
    static public let type:String = "_http._tcp"
    static public let defaultPort:Int32 = 8080
    static public let defaultDocument:String = "<!DOCTYPE html><html><head><meta charset=\"UTF-8\" /><title>lf</title></head><body>lf</body></html>"

    var document:String = HTTPService.defaultDocument
    private(set) var streams:[HTTPStream] = []

    public func addHTTPStream(stream:HTTPStream) {
        for i in 0..<streams.count {
            if (stream.name == streams[i].name) {
                return
            }
        }
        streams.append(stream)
    }

    public func removeHTTPStream(stream:HTTPStream) {
        for i in 0..<streams.count {
            if (stream.name == streams[i].name) {
                streams.removeAtIndex(i)
                return
            }
        }
    }

    func get(request:HTTPRequest, client:NetClient) {
        logger.verbose("\(request)")
        var response:HTTPResponse = HTTPResponse()
        response.headerFields["Connection"] = "close"

        defer {
            logger.verbose("\(response)")
            disconnect(client)
        }

        switch request.uri {
        case "/":
            response.headerFields["Content-Type"] = "text/html"
            response.body = [UInt8](document.utf8)
            client.doOutput(bytes: response.bytes)
        default:
            for stream in streams {
                guard let (mime, resource) = stream.getResource(request.uri) else {
                    break
                }
                response.headerFields["Content-Type"] = mime.rawValue
                switch mime {
                case .VideoMP2T:
                    if let info = try? NSFileManager.defaultManager().attributesOfItemAtPath(resource) {
                        response.headerFields["Content-Length"] = String(info["NSFileSize"]!)
                    }
                    client.doOutput(bytes: response.bytes)
                    client.doOutputFromURL(NSURL(fileURLWithPath: resource), length: 8 * 1024)
                default:
                    response.statusCode = HTTPStatusCode.OK.description
                    response.body = [UInt8](resource.utf8)
                    client.doOutput(bytes: response.bytes)
                }
                return
            }
            response.statusCode = HTTPStatusCode.NotFound.description
            response.headerFields["Connection"] = "close"
            client.doOutput(bytes: response.bytes)
        }
    }

    func client(inputBuffer client:NetClient) {
        guard let request:HTTPRequest = HTTPRequest(bytes: client.inputBuffer) else {
            disconnect(client)
            return
        }
        client.inputBuffer.removeAll()
        switch request.method {
        case "GET":
            get(request, client: client)
        default:
            break
        }
    }
}

