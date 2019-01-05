import Foundation

enum HTTPVersion: String {
    case version10 = "HTTP/1.0"
    case version11 = "HTTP/1.1"
}

extension HTTPVersion: CustomStringConvertible {
    // MARK: CustomStringConvertible
    var description: String {
        return rawValue
    }
}

// MARK: -
enum HTTPMethod: String {
    case get     = "GET"
    case post    = "POST"
    case put     = "PUT"
    case delete  = "DELETE"
    case head    = "HEAD"
    case options = "OPTIONS"
    case trace   = "TRACE"
    case connect = "CONNECT"
}

// MARK: -
enum HTTPStatusCode: Int {
    case `continue`                   = 100
    case switchingProtocols = 101
    case ok = 200
    case created = 201
    case accepted = 202
    case nonAuthoritative = 203
    case noContent = 204
    case resetContent = 205
    case partialContent = 206
    case multipleChoices = 300
    case movedParmanently = 301
    case found = 302
    case seeOther = 303
    case notModified = 304
    case useProxy = 305
    case temporaryRedirect = 307
    case badRequest = 400
    case unauthorixed = 401
    case paymentRequired = 402
    case forbidden = 403
    case notFound = 404
    case methodNotAllowed = 405
    case notAcceptable = 406
    case proxyAuthenticationRequired = 407
    case requestTimeOut = 408
    case conflict = 409
    case gone = 410
    case lengthRequired = 411
    case preconditionFailed = 412
    case requestEntityTooLarge = 413
    case requestURITooLarge = 414
    case unsupportedMediaType = 415
    case requestedRangeNotSatisfiable = 416
    case expectationFailed = 417
    case internalServerError = 500
    case notImplemented = 501
    case badGateway = 502
    case serviceUnavailable = 503
    case gatewayTimeOut = 504
    case httpVersionNotSupported = 505

    var message: String {
        switch self {
        case .continue:
            return "Continue"
        case .switchingProtocols:
            return "Switching Protocols"
        case .ok:
            return "OK"
        case .created:
            return "Created"
        case .accepted:
            return "Accepted"
        case .nonAuthoritative:
            return "Non-Authoritative Information"
        case .noContent:
            return "No Content"
        case .resetContent:
            return "Reset Content"
        case .partialContent:
            return "Partial Content"
        case .multipleChoices:
            return "Multiple Choices"
        case .movedParmanently:
            return "Moved Permanently"
        case .found:
            return "Found"
        case .seeOther:
            return "See Other"
        case .notModified:
            return "Not Modified"
        case .useProxy:
            return "Use Proxy"
        case .temporaryRedirect:
            return "Temporary Redirect"
        case .badRequest:
            return "Bad Request"
        case .unauthorixed:
            return "Unauthorixed"
        case .paymentRequired:
            return "Payment Required"
        case .forbidden:
            return "Forbidden"
        case .notFound:
            return "Not Found"
        case .methodNotAllowed:
            return "Method Not Allowed"
        case .notAcceptable:
            return "Not"
        case .proxyAuthenticationRequired:
            return "Proxy Authentication Required"
        case .requestTimeOut:
            return "Request Time-out"
        case .conflict:
            return "Conflict"
        case .gone:
            return "Gone"
        case .lengthRequired:
            return "Length Required"
        case .preconditionFailed:
            return "Precondition Failed"
        case .requestEntityTooLarge:
            return "Request Entity Too Large"
        case .requestURITooLarge:
            return "Request-URI Too Large"
        case .unsupportedMediaType:
            return "Unsupported Media Type"
        case .requestedRangeNotSatisfiable:
            return "Requested range not satisfiable"
        case .expectationFailed:
            return "Expectation Failed"
        case .internalServerError:
            return "Internal Server Error"
        case .notImplemented:
            return "Not Implemented"
        case .badGateway:
            return "Bad Gateway"
        case .serviceUnavailable:
            return "Service Unavailable"
        case .gatewayTimeOut:
            return "Gateway Time-out"
        case .httpVersionNotSupported:
            return "HTTP Version not supported"
        }
    }
}

extension HTTPStatusCode: CustomStringConvertible {
    // MARK: CustomStringConvertible
    var description: String {
        return "\(rawValue) \(message)"
    }
}

// MARK: -
open class HTTPService: NetService {
    open class var type: String {
        return "_http._tcp"
    }
    open class var defaultPort: Int32 {
        return 8080
    }
    open class var defaultDocument: String {
        return """
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8" />
  <title>HaishinKit</title>
</head>
<body></body>
</html>
"""
    }

    var document: String = HTTPService.defaultDocument

    func client(inputBuffer client: NetClient) {
        guard let request = HTTPRequest(data: client.inputBuffer) else {
            disconnect(client)
            return
        }
        client.inputBuffer.removeAll()
        if logger.isEnabledFor(level: .trace) {
            logger.trace("\(request): \(self)")
        }
        switch request.method {
        case "GET":
            get(request, client: client)
        case "POST":
            post(request, client: client)
        case "PUT":
            put(request, client: client)
        case "DELETE":
            delete(request, client: client)
        case "HEAD":
            head(request, client: client)
        case "OPTIONS":
            options(request, client: client)
        case "TRACE":
            trace(request, client: client)
        case "CONNECT":
            connect(request, client: client)
        default:
            notFound(request, client: client)
        }
    }

    open func get(_ request: HTTPRequest, client: NetClient) {
        notFound(request, client: client)
    }

    open func post(_ request: HTTPRequest, client: NetClient) {
        notFound(request, client: client)
    }

    open func put(_ request: HTTPRequest, client: NetClient) {
        notFound(request, client: client)
    }

    open func delete(_ request: HTTPRequest, client: NetClient) {
        notFound(request, client: client)
    }

    open func head(_ request: HTTPRequest, client: NetClient) {
        notFound(request, client: client)
    }

    open func options(_ requst: HTTPRequest, client: NetClient) {
        notFound(requst, client: client)
    }

    open func trace(_ request: HTTPRequest, client: NetClient) {
        notFound(request, client: client)
    }

    open func connect(_ request: HTTPRequest, client: NetClient) {
        notFound(request, client: client)
    }

    func notFound(_ request: HTTPRequest, client: NetClient) {
        var response = HTTPResponse()
        response.statusCode = HTTPStatusCode.notFound.description
        client.doOutput(data: response.data)
    }
}

open class HLSService: HTTPService {
    private(set) var streams: [HTTPStream] = []

    open func addHTTPStream(_ stream: HTTPStream) {
        for i in 0..<streams.count where stream.name == streams[i].name {
            return
        }
        streams.append(stream)
    }

    open func removeHTTPStream(_ stream: HTTPStream) {
        for i in 0..<streams.count where stream.name == streams[i].name {
            streams.remove(at: i)
            return
        }
    }

    override open func get(_ request: HTTPRequest, client: NetClient) {
        logger.trace("\(request)")
        var response: HTTPResponse = [
            // #141
            "Access-Control-Allow-Headers": "*",
            "Access-Control-Allow-Methods": "GET,HEAD,OPTIONS",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Expose-Headers": "*",
            "Connection": "close"
        ]

        defer {
            logger.trace("\(response)")
            disconnect(client)
        }

        switch request.uri {
        case "/":
            response.headerFields["Content-Type"] = "text/html"
            response.body = Data(document.utf8)
            client.doOutput(data: response.data)
        default:
            for stream in streams {
                guard let (mime, resource) = stream.getResource(request.uri) else {
                    break
                }
                response.statusCode = HTTPStatusCode.ok.description
                response.headerFields["Content-Type"] = mime.rawValue
                switch mime {
                case .videoMP2T:
                    if let info: [FileAttributeKey: Any] = try? FileManager.default.attributesOfItem(atPath: resource),
                        let length: Any = info[FileAttributeKey.size] {
                        response.headerFields["Content-Length"] = String(describing: length)
                    }
                    client.doOutput(data: response.data)
                    client.doOutputFromURL(URL(fileURLWithPath: resource), length: 8 * 1024)
                default:
                    response.statusCode = HTTPStatusCode.ok.description
                    response.body = Data(resource.utf8)
                    client.doOutput(data: response.data)
                }
                return
            }
            response.statusCode = HTTPStatusCode.notFound.description
            client.doOutput(data: response.data)
        }
    }
}
