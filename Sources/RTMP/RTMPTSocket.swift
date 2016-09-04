import Foundation

final internal class RTMPTSocket: NSObject, RTMPSocketCompatible {

    internal var timeout:Int64 = 0
    internal var timestamp:TimeInterval = 0
    internal var chunkSizeC:Int = RTMPChunk.defaultSize
    internal var chunkSizeS:Int = RTMPChunk.defaultSize
    internal var totalBytesIn:Int64 = 0
    internal var totalBytesOut:Int64 = 0
    internal var inputBuffer:[UInt8] = []
    internal var securityLevel:StreamSocketSecurityLevel = .none
    internal var objectEncoding:UInt8 = 0x00
    internal weak var delegate:RTMPSocketDelegate? = nil
    internal var connected:Bool = false {
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

    internal var readyState:RTMPSocket.ReadyState = .uninitialized {
        didSet {
            delegate?.didSet(readyState: readyState)
        }
    }

    private var events:[Event] = []
    private var index:Int64 = 0
    private var baseURL:URL!
    private var session:URLSession!
    private var connectionID:String!

    override internal init() {
        super.init()
    }

    internal func connect(withName:String, port:Int) {
        let config:URLSessionConfiguration = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "Content-Type": "application/x-fcs",
            "User-Agent": "Shockwave Flash",
        ]
        let scheme:String = securityLevel == .none ? "http" : "https"
        session = URLSession(configuration: config)
        baseURL = URL(string: "\(scheme)://\(withName):\(port)")!
        doRequest(pathComonent: "/fcs/ident2", data: Data([0x00]), completionHandler:didIdent2)
    }

    @discardableResult
    internal func doOutput(chunk:RTMPChunk) -> Int {
        var bytes:[UInt8] = []
        let chunks:[[UInt8]] = chunk.split(chunkSizeS)
        for chunk in chunks {
            bytes.append(contentsOf: chunk)
        }
        doOutput(bytes: bytes)
        return bytes.count
    }

    internal func close(isDisconnected:Bool) {
    }

    internal func deinitConnection(isDisconnected:Bool) {
    }

    internal func listen(data:Data?, response:URLResponse?, error:Error?) {
        if let error:Error = error {
            logger.error("\(error)")
            return
        }

        guard let data:Data = data else {
            return
        }

        logger.info("\(data.bytes):\(response):\(error)")

        var buffer:[UInt8] = data.bytes
        buffer.remove(at: 0)
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
            doOutput(bytes: c2packet.bytes)
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

    internal func didIdent2(data:Data?, response:URLResponse?, error:Error?) {
        logger.info("\(data?.bytes):\(response):\(error)")
        if let error:Error = error {
            logger.error("\(error)")
        }
        doRequest(pathComonent: "/open/1", data: Data([0x00]), completionHandler: didOpen)
    }

    internal func didOpen(data:Data?, response:URLResponse?, error:Error?) {
        logger.info("\(data?.bytes):\(response):\(error)")
        if let error:Error = error {
            logger.error("\(error)")
        }
        guard let data:Data = data else {
            return
        }
        connectionID = String(data: data, encoding: String.Encoding.utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        doRequest(pathComonent: "/idel/\(connectionID!)/0", data: Data([0x00]), completionHandler: didIdel0)
    }

    internal func didIdel0(data:Data?, response:URLResponse?, error:Error?) {
        logger.info("\(data?.bytes):\(response):\(error)")
        connected = true
    }

    @discardableResult
    final private func doOutput(bytes:[UInt8]) -> Int {
        guard let connectionID:String = connectionID else {
            return 0
        }
        index += 1
        doRequest(pathComonent: "/send/\(connectionID)/\(index)", data: Data(bytes), completionHandler: listen)
        return bytes.count
    }

    private func idel() {
        guard let connectionID:String = connectionID else {
            return
        }
        index += 1
        doRequest(pathComonent: "/idel/\(connectionID)/\(index)", data: Data([0x00]), completionHandler: listen)
    }

    private func doRequest(pathComonent: String, data:Data, completionHandler: ((Data?, URLResponse?, Error?) -> Void)) {
        var request:URLRequest = URLRequest(url: baseURL.appendingPathComponent(pathComonent))
        request.httpMethod = "POST"
        let task:URLSessionUploadTask = session.uploadTask(with: request, from: data, completionHandler: completionHandler)
        task.resume()
        logger.verbose("\(request)")
    }
}
