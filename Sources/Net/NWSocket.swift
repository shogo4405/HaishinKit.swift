import Foundation
#if canImport(Network)
    import Network
#endif

@available(iOS 12.0, macOS 10.14, tvOS 12.0, *)
open class NWSocket: NetSocketCompatible {
    var windowSizeC = Int(UInt8.max)
    open var timeout: Int = NetSocket.defaultTimeout

    open private(set) var queueBytesOut: Int64 = 0
    open private(set) var totalBytesIn: Int64 = 0 {
        didSet {
            didSetTotalBytesIn?(totalBytesIn)
        }
    }

    open private(set) var totalBytesOut: Int64 = 0 {
        didSet {
            didSetTotalBytesOut?(totalBytesOut)
        }
    }

    open internal(set) var connected: Bool = false {
        didSet {
            didSetConnected?(connected)
        }
    }

    open var securityLevel: StreamSocketSecurityLevel = .none
    open var qualityOfService: DispatchQoS = .default
    open var inputHandler: (() -> Void)?
    open var timeoutHandler: (() -> Void)?
    open var didSetTotalBytesIn: ((Int64) -> Void)?
    open var didSetTotalBytesOut: ((Int64) -> Void)?
    open var didSetConnected: ((Bool) -> Void)?
    open var inputBuffer = Data()

    private var nwParams: NWParameters = .tcp
    private var nwHost: NWEndpoint.Host?
    private var nwPort: NWEndpoint.Port?
    private var conn: NWConnection?
    private lazy var queue = DispatchQueue(label: "com.haishinkit.HaishinKit.NWSocket.queue", qos: qualityOfService)
    private lazy var inputQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.NWSocket.input", qos: qualityOfService)
    private lazy var outputQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.NWSocket.output", qos: qualityOfService)

    init(_ nwParams: NWParameters) {
        self.nwParams = nwParams
    }
    deinit {
        conn?.forceCancel()
        conn = nil
    }

    public func connect(withName: String, port: Int) {
        nwHost = NWEndpoint.Host(withName)
        nwPort = NWEndpoint.Port(integerLiteral: UInt16(port))
        initConnection()
    }

    func initConnection() {
        if conn != nil {
            conn?.cancel()
            conn = nil
        }
        guard let nwHost = self.nwHost else {
            return
        }
        guard let nwPort = self.nwPort else {
            return
        }
        self.connected = false
        let conn = NWConnection(to: NWEndpoint.hostPort(host: nwHost, port: nwPort), using: nwParams)
        conn.stateUpdateHandler = self.stateDidChange(to:)
        conn.start(queue: queue)
        receiveLoop(conn)
        if 0 < timeout {
            outputQueue.asyncAfter(deadline: .now() + .seconds(timeout)) {
                guard let timeoutHandler = self.timeoutHandler else {
                    return
                }
                timeoutHandler()
            }
        }
        self.conn = conn
    }

    public func close(isDisconnected: Bool) {
        outputQueue.async {
            self.deinitConnection(isDisconnected: isDisconnected)
            self.conn?.cancel()
            self.conn = nil
            self.connected = false
        }
    }

    func deinitConnection(isDisconnected: Bool) {
        timeoutHandler = nil
        inputHandler = nil
        didSetTotalBytesIn = nil
        didSetTotalBytesOut = nil
        didSetConnected = nil
        outputQueue = .init(label: outputQueue.label, qos: qualityOfService)
        inputBuffer.removeAll()
    }

    func stateDidChange(to state: NWConnection.State) {
        switch state {
        case .ready:
            timeoutHandler = nil
            connected = true
        case .failed:
            close(isDisconnected: true)
        case .cancelled:
            close(isDisconnected: true)
        default:
            break
        }
    }

    func receiveLoop(_ conn: NWConnection) {
        let receiveCompletion = { [weak self] (_ data: Data?, _ ctx: NWConnection.ContentContext?, _ isComplete: Bool, _ error: NWError?) -> Void in
            guard let me = self else {
                return
            }
            me.receive(data, ctx, isComplete, error)
            if me.connected {
                me.inputQueue.async { [weak me] () -> Void in
                    me?.receiveLoop(conn)
                }
            }
        }
        inputQueue.async { [weak self] () -> Void in
            guard let windowSizeC = self?.windowSizeC else {
                return
            }
            conn.receive(minimumIncompleteLength: 0, maximumLength: windowSizeC, completion: receiveCompletion)
        }
    }

    func receive(_ data: Data?, _ ctx: NWConnection.ContentContext?, _ isComplete: Bool, _ error: NWError?) {
        if error != nil {
            close(isDisconnected: true)
            return
        }
        guard let d = data else {
            return
        }
        inputBuffer.append(d)
        totalBytesIn += Int64(d.count)
        inputHandler?()
    }

    @discardableResult
    public func doOutput(data: Data, locked: UnsafeMutablePointer<UInt32>? = nil) -> Int {
        OSAtomicAdd64(Int64(data.count), &queueBytesOut)
        outputQueue.async {
            let sendCompletion = NWConnection.SendCompletion.contentProcessed { error in
                if error != nil {
                    self.close(isDisconnected: true)
                    return
                }
                self.totalBytesOut += Int64(data.count)
                OSAtomicAdd64(Int64(data.count), &self.queueBytesOut)
                if locked != nil {
                    OSAtomicAnd32Barrier(0, locked!)
                }
            }
            self.conn?.send(content: data, completion: sendCompletion)
        }
        return data.count
    }
}
