import Foundation

open class NetService: NSObject {

    open var txtData:Data? {
        return nil
    }

    let lockQueue:DispatchQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.NetService.lock")
    var networkQueue:DispatchQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.NetService.network")

    private(set) var domain:String
    private(set) var name:String
    private(set) var port:Int32
    private(set) var type:String
    private(set) var running:Bool = false
    private(set) var clients:[NetClient] = []
    private(set) var service:Foundation.NetService!
    private var runloop:RunLoop!

    public init(domain:String, type:String, name:String, port:Int32) {
        self.domain = domain
        self.name = name
        self.port = port
        self.type = type
    }

    func disconnect(_ client:NetClient) {
        lockQueue.sync {
            guard let index:Int = clients.index(of: client) else {
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
        if let runloop:RunLoop = runloop {
            service.remove(from: runloop, forMode: RunLoopMode.defaultRunLoopMode)
            CFRunLoopStop(runloop.getCFRunLoop())
        }
        service.stop()
        service.delegate = nil
        service = nil
        runloop = nil
    }

    private func initService() {
        runloop = RunLoop.current
        service = Foundation.NetService(domain: domain, type: type, name: name, port: port)
        service.delegate = self
        service.setTXTRecord(txtData)
        service.schedule(in: runloop, forMode: RunLoopMode.defaultRunLoopMode)
        if (type.contains("._udp")) {
            service.publish()
        } else {
            service.publish(options: Foundation.NetService.Options.listenForConnections)
        }
        runloop.run()
    }
}

extension NetService: NetServiceDelegate {
    // MARK: NSNetServiceDelegate
    public func netService(_ sender: Foundation.NetService, didAcceptConnectionWith inputStream: InputStream, outputStream: OutputStream) {
        lockQueue.sync {
            let client:NetClient = NetClient(service: sender, inputStream: inputStream, outputStream: outputStream)
            clients.append(client)
            client.delegate = self
            client.acceptConnection()
        }
    }
}

extension NetService: NetClientDelegate {
    // MARK: NetClientDelegate
}

extension NetService: Runnable {
    // MARK: Runnbale
    final public func startRunning() {
        lockQueue.async {
            if (self.running) {
                return
            }
            self.willStartRunning()
            self.running = true
        }
    }

    final public func stopRunning() {
        lockQueue.async {
            if (!self.running) {
                return
            }
            self.willStopRunning()
            self.running = false
        }
    }
}
