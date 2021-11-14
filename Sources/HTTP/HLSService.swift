import Foundation

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
            response.statusCode = HTTPStatusCode.ok.description
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
                    doOutputFromURL(client, url: URL(fileURLWithPath: resource), length: 8 * 1024)
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

    func doOutputFromURL(_ client: NetClient, url: URL, length: Int) {
        do {
            let fileHandle: FileHandle = try FileHandle(forReadingFrom: url)
            defer {
                fileHandle.closeFile()
            }
            let endOfFile = Int(fileHandle.seekToEndOfFile())
            for i in 0..<Int(endOfFile / length) {
                fileHandle.seek(toFileOffset: UInt64(i * length))
                client.doOutput(data: fileHandle.readData(ofLength: length))
            }
            let remain: Int = endOfFile % length
            if 0 < remain {
                client.doOutput(data: fileHandle.readData(ofLength: remain))
            }
        } catch let error as NSError {
            logger.error("\(error)")
        }
    }
}
