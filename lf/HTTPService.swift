import UIKit
import Foundation

class HTTPRequest:NSObject {
    
    enum Header:String {
        case Host = "Host"
        case ContentType = "Content-Type"
        case ContentLength = "Content-Length"
        case UserAgent = "User-Agent"
    }
    
    var uri:String = ""
    var method:String = ""
    var version:String = ""
    var headers:[String:String] = [:]
    var content:[UInt8] = []
    
    override var description:String {
        var description:String = "HTTPRequest{"
        description += "uri=\(uri),"
        description += "method=\(method),"
        description += "version=\(version),"
        description += "headers=\(headers),"
        description += "content=\(content)"
        description += "}"
        return description
    }
    
    override init () {
    }
    
    init (method:String, uri:String, version:String) {
        self.method = method
        self.uri = uri
        self.version = version
    }
    
    private var _bytes:[UInt8] = []
    var bytes:[UInt8] {
        set {
            if (_bytes == newValue) {
                return
            }
            
            _bytes = newValue
            
            let body:String = String(bytes: bytes, encoding: NSASCIIStringEncoding)!
            var lines:[String] = body.componentsSeparatedByString("\r\n")
            let first:[String] = lines.removeAtIndex(0).componentsSeparatedByString(" ")
            
            method = first[0]
            uri = first[1]
            version = first[2]
            
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
            if (!_bytes.isEmpty) {
                return _bytes
            }
            
            var lines:[String] = []
            lines.append("\(method) \(uri) \(version)")
            for (key, value) in headers {
                lines.append("\(key): \(value)")
            }
            lines.append("")
            
            _bytes += lines.joinWithSeparator("\r\n").utf8
            _bytes += content
            
            return _bytes
        }
    }
}

class HTTPResponse:HTTPRequest {
    override var bytes:[UInt8] {
        set {
            super.bytes = newValue
        }
        get {
            
            var lines:[String] = []
            lines.append("\(version) 200 OK")
            for (key, value) in headers {
                lines.append("\(key): \(value)")
            }
            lines.append("")
            
            _bytes += lines.joinWithSeparator("\r\n").utf8
            _bytes += content
            
            return _bytes
        }
    }
}

public class AbstractNetService:NSObject, NSNetServiceDelegate, NetServiceClientDeledate {

    var clients:[NetServiceClient] = []

    private var domain:String
    private var name:String
    private var port:Int32
    private var type:String

    private var running:Bool = false
    private var service:NSNetService!
    private let lockQueue:dispatch_queue_t = dispatch_queue_create("com.github.shogo4405.lf.AbstractNetService.lock", DISPATCH_QUEUE_SERIAL)

    public init (domain:String, type:String, name:String, port:Int32) {
        self.domain = domain
        self.name = name
        self.port = port
        self.type = type
    }

    final public func startRunning() {
        dispatch_sync(lockQueue) {
            if (self.running) {
                return
            }
            self.onStartRunning()
            self.running = true
        }
    }

    final public func stopRunning() {
        dispatch_sync(lockQueue) {
            if (!self.running) {
                return
            }
            self.onStartRunning()
            self.clients.removeAll(keepCapacity: true)
            self.running = false
        }
    }

    public func netService(sender: NSNetService, didAcceptConnectionWithInputStream inputStream: NSInputStream, outputStream: NSOutputStream) {
        let client:NetServiceClient = NetServiceClient(service: sender, inputStream: inputStream, outputStream: outputStream)
        clients.append(client)
        client.delegate = self
        client.acceptConnection()
    }

    func onStartRunning() {
        service = NSNetService(domain: domain, type: type, name: name, port: port)
        service.delegate = self
        service.setTXTRecordData(createRecordData())
        service.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSRunLoopCommonModes)
        service.publishWithOptions(NSNetServiceOptions.ListenForConnections)
    }

    func onStopRunning() {
        service.stop()
        service.delegate = nil
        service.removeFromRunLoop(NSRunLoop.currentRunLoop(), forMode: NSRunLoopCommonModes)
        service = nil
    }

    func createRecordData() -> NSData? {
        return nil
    }
}

public class HTTPService:AbstractNetService {
    public static let type:String = "_http._tcp"
    public static let defaultPort:Int = 8080
}
