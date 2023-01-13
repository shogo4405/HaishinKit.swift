import Foundation

/// The NetService class creates a two-way connection between a client and a server as a server.
open class NetService: NSObject {
    /// The TXT record for the receiver.
    open var txtData: Data? {
        nil
    }

    /// The domain for the service.
    public let domain: String
    /// The network service type.
    public let type: String
    /// The name of service.
    public let name: String
    /// The port.
    public let port: Int32
    /// The service is running or not.
    public private(set) var isRunning: Atomic<Bool> = .init(false)
    /// The current connected client objects.
    public private(set) var clients: [NetClient] = []

    let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.NetService.lock")
    var networkQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.NetService.network")
    private(set) var service: Foundation.NetService!
    private var runloop: RunLoop!

    /// Create a new NetService object.
    public init(domain: String, type: String, name: String, port: Int32) {
        self.domain = domain
        self.name = name
        self.port = port
        self.type = type
    }

    func disconnect(_ client: NetClient) {
        lockQueue.sync {
            guard let index: Int = clients.firstIndex(of: client) else {
                return
            }
            clients.remove(at: index)
            client.delegate = nil
            client.close(isDisconnected: true)
        }
    }

    func willStartRunning() {
        networkQueue.async {
            self.initService()
        }
    }

    func willStopRunning() {
        if let runloop: RunLoop = runloop {
            service.remove(from: runloop, forMode: RunLoop.Mode.default)
            CFRunLoopStop(runloop.getCFRunLoop())
        }
        service.stop()
        service.delegate = nil
        service = nil
        runloop = nil
    }

    private func initService() {
        runloop = .current
        service = Foundation.NetService(domain: domain, type: type, name: name, port: port)
        service.delegate = self
        service.setTXTRecord(txtData)
        service.schedule(in: runloop, forMode: RunLoop.Mode.default)
        if type.contains("._udp") {
            service.publish()
        } else {
            service.publish(options: .listenForConnections)
        }
        runloop.run()
    }
}

extension NetService: NetServiceDelegate {
    // MARK: NSNetServiceDelegate
    public func netService(_ sender: Foundation.NetService, didAcceptConnectionWith inputStream: InputStream, outputStream: OutputStream) {
        lockQueue.sync {
            let client = NetClient(inputStream: inputStream, outputStream: outputStream)
            clients.append(client)
            client.delegate = self
            client.acceptConnection()
        }
    }
}

extension NetService: NetClientDelegate {
    // MARK: NetClientDelegate
    func client(client: NetClient, isDisconnected: Bool) {
        disconnect(client)
    }
}

extension NetService: Running {
    // MARK: Runnbale
    public func startRunning() {
        lockQueue.async {
            if self.isRunning.value {
                return
            }
            self.willStartRunning()
            self.isRunning.mutate { $0 = true }
        }
    }

    public func stopRunning() {
        lockQueue.async {
            if !self.isRunning.value {
                return
            }
            self.willStopRunning()
            self.isRunning.mutate { $0 = false }
        }
    }
}
