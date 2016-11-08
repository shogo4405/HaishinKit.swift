import Foundation

open class NetService: NSObject {

    var recordData:Data? {
        return nil
    }

    let lockQueue:DispatchQueue = DispatchQueue(
        label: "com.github.shogo4405.lf.NetService.lock", attributes: []
    )
    var networkQueue:DispatchQueue = DispatchQueue(
        label: "com.github.shogo4405.lf.NetService.network", attributes: []
    )

    fileprivate(set) var domain:String
    fileprivate(set) var name:String
    fileprivate(set) var port:Int32
    fileprivate(set) var type:String
    fileprivate(set) var running:Bool = false
    fileprivate(set) var clients:[NetClient] = []
    fileprivate(set) var service:Foundation.NetService!
    fileprivate var runloop:RunLoop!

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

    fileprivate func initService() {
        runloop = RunLoop.current
        service = Foundation.NetService(domain: domain, type: type, name: name, port: port)
        service.delegate = self
        service.setTXTRecord(recordData)
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
