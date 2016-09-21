import Foundation

final class RTMPTSocket: NSObject, RTMPSocketCompatible {
    static let contentType:String = "application/x-fcs"

    var timeout:Int64 = 0
    var timestamp:TimeInterval = 0
    var chunkSizeC:Int = RTMPChunk.defaultSize
    var chunkSizeS:Int = RTMPChunk.defaultSize
    var totalBytesIn:Int64 = 0
    var totalBytesOut:Int64 = 0
    var inputBuffer:[UInt8] = []
    var securityLevel:StreamSocketSecurityLevel = .none
    var objectEncoding:UInt8 = 0x00
    weak var delegate:RTMPSocketDelegate? = nil
    var connected:Bool = false {
        didSet {
            if (connected) {
                timestamp = Date().timeIntervalSince1970
                let c1packet:ByteArray = ByteArray()
                    .writeUInt8(RTMPSocket.protocolVersion)
                    .writeInt32(Int32(timestamp))
                    .writeBytes([0x00, 0x00, 0x00, 0x00])
                for _ in 0..<RTMPSocket.sigSize - 8 {
                    c1packet.writeUInt8(UInt8(arc4random_uniform(0xff)))
                }
                doOutput(bytes: c1packet.bytes)
                readyState = .versionSent
                return
            }
            readyState = .closed
            for event in events {
                delegate?.dispatch(event: event)
            }
            events.removeAll()
        }
    }

    var readyState:RTMPSocket.ReadyState = .uninitialized {
        didSet {
            delegate?.didSet(readyState: readyState)
        }
    }

    private var delay:UInt8 = 1
    private var index:Int64 = 0
    private var events:[Event] = []
    private var baseURL:URL!
    private var session:URLSession!
    private var c2packet:[UInt8] = []
    private var isPending:Bool = false
    private let outputQueue:DispatchQueue = DispatchQueue(label: "com.github.shgoo4405.lf.RTMPTSocket.output")
    private var connectionID:String!
    private var outputBuffer:[UInt8] = []
    private var lastResponse:Date = Date()

    override init() {
        super.init()
    }

    func connect(withName:String, port:Int) {
        let config:URLSessionConfiguration = URLSessionConfiguration.default
        config.httpShouldUsePipelining = true
        config.httpAdditionalHeaders = [
            "Content-Type": RTMPTSocket.contentType,
            "User-Agent": "Shockwave Flash",
        ]
        let scheme:String = securityLevel == .none ? "http" : "https"
        session = URLSession(configuration: config)
        baseURL = URL(string: "\(scheme)://\(withName):\(port)")!
        doRequest("/fcs/ident2", Data([0x00]), didIdent2)
    }

    @discardableResult
    func doOutput(chunk:RTMPChunk) -> Int {
        var bytes:[UInt8] = []
        let chunks:[[UInt8]] = chunk.split(chunkSizeS)
        for chunk in chunks {
            bytes.append(contentsOf: chunk)
        }
        outputQueue.sync {
            self.outputBuffer.append(contentsOf: bytes)
            if (!self.isPending) {
                self.isPending = true
                self.doOutput(bytes: self.outputBuffer)
                self.outputBuffer.removeAll()
            }
        }
        return bytes.count
    }

    func close(isDisconnected:Bool) {
        deinitConnection(isDisconnected: isDisconnected)
    }

    func deinitConnection(isDisconnected:Bool) {
        if (isDisconnected) {
            let data:ASObject = (readyState == .handshakeDone) ?
                RTMPConnection.Code.connectClosed.data("") : RTMPConnection.Code.connectFailed.data("")
            events.append(Event(type: Event.RTMP_STATUS, bubbles: false, data: data))
        }
        guard let connectionID:String = connectionID else {
            return
        }
        doRequest("/close/\(connectionID)", Data(), didClose)
    }

    private func listen(data:Data?, response:URLResponse?, error:Error?) {
        if (logger.isEnabledFor(level: .verbose)) {
            logger.verbose("\(data):\(response):\(error)")
        }

        if let error:Error = error {
            logger.error("\(error)")
            return
        }

        lastResponse = Date()
        outputQueue.sync {
            if (self.outputBuffer.isEmpty) {
                self.isPending = false
            } else {
                self.doOutput(bytes: outputBuffer)
                self.outputBuffer.removeAll()
            }
        }

        guard
            let response:HTTPURLResponse = response as? HTTPURLResponse,
            let contentType:String = response.allHeaderFields["Content-Type"] as? String,
            let data:Data = data, contentType == RTMPTSocket.contentType else {
            return
        }

        var buffer:[UInt8] = data.bytes
        delay = buffer.remove(at: 0)
        inputBuffer.append(contentsOf: buffer)

        switch readyState {
        case .versionSent:
            if (inputBuffer.count < RTMPSocket.sigSize + 1) {
                break
            }
            let c2packet:ByteArray = ByteArray()
                .writeBytes(Array(inputBuffer[1...4]))
                .writeInt32(Int32(Date().timeIntervalSince1970 - timestamp))
                .writeBytes(Array(inputBuffer[9...RTMPSocket.sigSize]))
            self.c2packet = c2packet.bytes
            inputBuffer = Array(inputBuffer[RTMPSocket.sigSize + 1..<inputBuffer.count])
            readyState = .ackSent
            fallthrough
        case .ackSent:
            if (inputBuffer.count < RTMPSocket.sigSize) {
                break
            }
            inputBuffer.removeAll()
            readyState = .handshakeDone
        case .handshakeDone:
            if (inputBuffer.isEmpty){
                break
            }
            let bytes:[UInt8] = inputBuffer
            inputBuffer.removeAll()
            delegate?.listen(bytes: bytes)
        default:
            break
        }
    }

    private func didIdent2(data:Data?, response:URLResponse?, error:Error?) {
        if let error:Error = error {
            logger.error("\(error)")
        }
        doRequest("/open/1", Data([0x00]), didOpen)
        if (logger.isEnabledFor(level: .verbose)) {
            logger.verbose("\(data?.bytes):\(response)")
        }
    }

    private func didOpen(data:Data?, response:URLResponse?, error:Error?) {
        if let error:Error = error {
            logger.error("\(error)")
        }
        guard let data:Data = data else {
            return
        }
        connectionID = String(data: data, encoding: String.Encoding.utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        doRequest("/idel/\(connectionID!)/0", Data([0x00]), didIdel0)
        if (logger.isEnabledFor(level: .verbose)) {
            logger.verbose("\(data.bytes):\(response)")
        }
    }

    private func didIdel0(data:Data?, response:URLResponse?, error:Error?) {
        if let error:Error = error {
            logger.error("\(error)")
        }
        connected = true
        if (logger.isEnabledFor(level: .verbose)) {
            logger.verbose("\(data?.bytes):\(response)")
        }
    }

    private func didClose(data:Data?, response:URLResponse?, error:Error?) {
        if let error:Error = error {
            logger.error("\(error)")
        }
        connected = false
        if (logger.isEnabledFor(level: .verbose)) {
            logger.verbose("\(data?.bytes):\(response)")
        }
    }

    private func idel() {
        guard let connectionID:String = connectionID, connected else {
            return
        }
        let index:Int64 = OSAtomicIncrement64(&self.index)
        doRequest("/idel/\(connectionID)/\(index)", Data([0x00]), didIdel)
    }

    private func didIdel(data:Data?, response:URLResponse?, error:Error?) {
        listen(data: data, response: response, error: error)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: idel)
    }

    @discardableResult
    final private func doOutput(bytes:[UInt8]) -> Int {
        guard let connectionID:String = connectionID, connected else {
            return 0
        }
        let index:Int64 = OSAtomicIncrement64(&self.index)
        doRequest("/send/\(connectionID)/\(index)", Data(c2packet + bytes), listen)
        c2packet.removeAll()
        return bytes.count
    }

    private func doRequest(_ pathComonent: String,_ data:Data,_ completionHandler: @escaping ((Data?, URLResponse?, Error?) -> Void)) {
        var request:URLRequest = URLRequest(url: baseURL.appendingPathComponent(pathComonent))
        request.httpMethod = "POST"
        session.uploadTask(with: request, from: data, completionHandler: completionHandler).resume()
        if (logger.isEnabledFor(level: .verbose)) {
            logger.verbose("\(request)")
        }
    }
}
