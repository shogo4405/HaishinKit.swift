import Foundation

final class RTMPTSocket: NSObject, RTMPSocketCompatible {
    static let contentType: String = "application/x-fcs"

    var timeout: Int64 = 0
    var chunkSizeC: Int = RTMPChunk.defaultSize
    var chunkSizeS: Int = RTMPChunk.defaultSize
    var inputBuffer = Data()
    var securityLevel: StreamSocketSecurityLevel = .none
    weak var delegate: RTMPSocketDelegate?
    var connected: Bool = false {
        didSet {
            if connected {
                handshake.timestamp = Date().timeIntervalSince1970
                doOutput(data: handshake.c0c1packet)
                readyState = .versionSent
                return
            }
            timer = nil
            readyState = .closed
            for event in events {
                delegate?.dispatch(event: event)
            }
            events.removeAll()
        }
    }

    var timestamp: TimeInterval {
        return handshake.timestamp
    }

    var readyState: RTMPSocket.ReadyState = .uninitialized {
        didSet {
            delegate?.didSetReadyState(readyState)
        }
    }

    private(set) var totalBytesIn: Int64 = 0
    private(set) var totalBytesOut: Int64 = 0
    private(set) var queueBytesOut: Int64 = 0
    private var timer: Timer? {
        didSet {
            oldValue?.invalidate()
            if let timer: Timer = timer {
                RunLoop.main.add(timer, forMode: RunLoop.Mode.common)
            }
        }
    }

    private var delay: UInt8 = 1
    private var index: Int64 = 0
    private var events: [Event] = []
    private var baseURL: URL!
    private var session: URLSession!
    private var request: URLRequest!
    private var c2packet = Data()
    private var handshake = RTMPHandshake()
    private let outputQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.RTMPTSocket.output")
    private var connectionID: String?
    private var isRequesting: Bool = false
    private var outputBuffer = Data()
    private var lastResponse = Date()
    private var lastRequestPathComponent: String?
    private var lastRequestData: Data?
    private var isRetryingRequest: Bool = true

    override init() {
        super.init()
    }

    func connect(withName: String, port: Int) {
        let config = URLSessionConfiguration.default
        config.httpShouldUsePipelining = true
        config.httpAdditionalHeaders = [
            "Content-Type": RTMPTSocket.contentType,
            "User-Agent": "Shockwave Flash"
        ]
        let scheme: String = securityLevel == .none ? "http" : "https"
        session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        baseURL = URL(string: "\(scheme)://\(withName):\(port)")!
        doRequest("/fcs/ident2", Data([0x00]), didIdent2)
        timer = Timer(timeInterval: 0.1, target: self, selector: #selector(on(timer:)), userInfo: nil, repeats: true)
    }

    @discardableResult
    func doOutput(chunk: RTMPChunk, locked: UnsafeMutablePointer<UInt32>? = nil) -> Int {
        var bytes: [UInt8] = []
        let chunks: [Data] = chunk.split(chunkSizeS)
        for chunk in chunks {
            bytes.append(contentsOf: chunk)
        }

        outputQueue.sync {
            self.outputBuffer.append(contentsOf: bytes)
            if !self.isRequesting {
                self.doOutput(data: self.outputBuffer)
                self.outputBuffer.removeAll()
            }
        }
        if locked != nil {
            OSAtomicAnd32Barrier(0, locked!)
        }
        return bytes.count
    }

    func close(isDisconnected: Bool) {
        deinitConnection(isDisconnected: isDisconnected)
    }

    func deinitConnection(isDisconnected: Bool) {
        if isDisconnected {
            let data: ASObject = (readyState == .handshakeDone) ?
                RTMPConnection.Code.connectClosed.data("") : RTMPConnection.Code.connectFailed.data("")
            events.append(Event(type: Event.RTMP_STATUS, bubbles: false, data: data))
        }
        guard let connectionID: String = connectionID else {
            return
        }
        doRequest("/close/\(connectionID)", Data(), didClose)
    }

    private func listen(data: Data?, response: URLResponse?, error: Error?) {

        lastResponse = Date()

        if logger.isEnabledFor(level: .trace) {
            logger.trace("\(String(describing: data)): \(String(describing: response)): \(String(describing: error))")
        }

        if let error: Error = error {
            logger.error("\(error)")

            if let lastRequestPathComponent: String = self.lastRequestPathComponent,
               let lastRequestData: Data = self.lastRequestData, !isRetryingRequest {
                if logger.isEnabledFor(level: .trace) {
                    logger.trace("Will retry request for path=\(lastRequestPathComponent)")
                }
                outputQueue.sync {
                    isRetryingRequest = true
                    doRequest(lastRequestPathComponent, lastRequestData, listen)
                }
            }

            return
        }

        isRetryingRequest = false

        outputQueue.sync {
            if self.outputBuffer.isEmpty {
                self.isRequesting = false
            } else {
                self.doOutput(data: outputBuffer)
                self.outputBuffer.removeAll()
            }
        }

        guard
            let response: HTTPURLResponse = response as? HTTPURLResponse,
            let contentType: String = response.allHeaderFields["Content-Type"] as? String,
            let data: Data = data, contentType == RTMPTSocket.contentType else {
            return
        }

        var buffer: [UInt8] = data.bytes
        OSAtomicAdd64(Int64(buffer.count), &totalBytesIn)
        delay = buffer.remove(at: 0)
        inputBuffer.append(contentsOf: buffer)

        switch readyState {
        case .versionSent:
            if inputBuffer.count < RTMPHandshake.sigSize + 1 {
                break
            }
            c2packet = handshake.c2packet(inputBuffer)
            inputBuffer.removeSubrange(0...RTMPHandshake.sigSize)
            readyState = .ackSent
            fallthrough
        case .ackSent:
            if inputBuffer.count < RTMPHandshake.sigSize {
                break
            }
            inputBuffer.removeAll()
            readyState = .handshakeDone
        case .handshakeDone:
            if inputBuffer.isEmpty {
                break
            }
            let data: Data = inputBuffer
            inputBuffer.removeAll()
            delegate?.listen(data)
        default:
            break
        }
    }

    private func didIdent2(data: Data?, response: URLResponse?, error: Error?) {
        if let error: Error = error {
            logger.error("\(error)")
        }
        doRequest("/open/1", Data([0x00]), didOpen)
        if logger.isEnabledFor(level: .trace) {
            logger.trace("\(String(describing: data?.bytes)): \(String(describing: response))")
        }
    }

    private func didOpen(data: Data?, response: URLResponse?, error: Error?) {
        if let error: Error = error {
            logger.error("\(error)")
        }
        guard let data: Data = data else {
            return
        }
        connectionID = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        doRequest("/idle/\(connectionID!)/0", Data([0x00]), didIdle0)
        if logger.isEnabledFor(level: .trace) {
            logger.trace("\(data.bytes): \(String(describing: response))")
        }
    }

    private func didIdle0(data: Data?, response: URLResponse?, error: Error?) {
        if let error: Error = error {
            logger.error("\(error)")
        }
        connected = true
        if logger.isEnabledFor(level: .trace) {
            logger.trace("\(String(describing: data?.bytes)): \(String(describing: response))")
        }
    }

    private func didClose(data: Data?, response: URLResponse?, error: Error?) {
        if let error: Error = error {
            logger.error("\(error)")
        }
        connected = false
        if logger.isEnabledFor(level: .trace) {
            logger.trace("\(String(describing: data?.bytes)): \(String(describing: response))")
        }
    }

    private func idle() {
        guard let connectionID: String = connectionID, connected else {
            return
        }
        outputQueue.sync {
            let index: Int64 = OSAtomicIncrement64(&self.index)
            doRequest("/idle/\(connectionID)/\(index)", Data([0x00]), didIdle)
        }
    }

    private func didIdle(data: Data?, response: URLResponse?, error: Error?) {
        listen(data: data, response: response, error: error)
    }

    @objc
    private func on(timer: Timer) {
        guard (Double(delay) / 10) < abs(lastResponse.timeIntervalSinceNow), !isRequesting else {
            return
        }
        idle()
    }

    @discardableResult
    private func doOutput(data: Data) -> Int {
        guard let connectionID: String = connectionID, connected else {
            return 0
        }
        let index: Int64 = OSAtomicIncrement64(&self.index)
        doRequest("/send/\(connectionID)/\(index)", c2packet + data, listen)
        c2packet.removeAll()
        return data.count
    }

    private func doRequest(_ pathComponent: String, _ data: Data, _ completionHandler: @escaping ((Data?, URLResponse?, Error?) -> Void)) {
        isRequesting = true
        lastRequestPathComponent = pathComponent
        lastRequestData = data
        request = URLRequest(url: baseURL.appendingPathComponent(pathComponent))
        request.httpMethod = "POST"
        session.uploadTask(with: request, from: data, completionHandler: completionHandler).resume()
        if logger.isEnabledFor(level: .trace) {
            logger.trace("\(String(describing: self.request))")
        }
    }
}

// MARK: -
extension RTMPTSocket: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        OSAtomicAdd64(bytesSent, &totalBytesOut)
    }
}
