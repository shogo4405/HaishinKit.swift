import Foundation

// MARK: - NetService
public class NetService: NSObject {

    var recordData:NSData? {
        return nil
    }

    let lockQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.NetService.lock", DISPATCH_QUEUE_SERIAL
    )
    var networkQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.NetService.nwtwork", DISPATCH_QUEUE_SERIAL
    )
    
    private(set) var domain:String
    private(set) var name:String
    private(set) var port:Int32
    private(set) var type:String
    private(set) var running:Bool = false
    private(set) var clients:[NetClient] = []
    private(set) var service:NSNetService!
    private var runloop:NSRunLoop!

    public init(domain:String, type:String, name:String, port:Int32) {
        self.domain = domain
        self.name = name
        self.port = port
        self.type = type
    }

    func disconnect(client:NetClient) {
        if let index:Int = clients.indexOf(client) {
            clients.removeAtIndex(index)
            client.delegate = nil
            client.close(true)
        }
    }

    func willStartRunning() {
        dispatch_async(networkQueue) {
            self.initService()
        }
    }

    func willStopRunning() {
        if let runloop:NSRunLoop = runloop {
            service.removeFromRunLoop(runloop, forMode: NSDefaultRunLoopMode)
            CFRunLoopStop(runloop.getCFRunLoop())
        }
        service.stop()
        service.delegate = nil
        service = nil
        runloop = nil
    }

    private func initService() {
        runloop = NSRunLoop.currentRunLoop()
        service = NSNetService(domain: domain, type: type, name: name, port: port)
        service.delegate = self
        service.setTXTRecordData(recordData)
        service.scheduleInRunLoop(runloop, forMode: NSDefaultRunLoopMode)
        service.publishWithOptions(NSNetServiceOptions.ListenForConnections)
        runloop.run()
    }
}

// MARK: NSNetServiceDelegate
extension NetService: NSNetServiceDelegate {
    public func netService(sender: NSNetService, didNotPublish errorDict: [String : NSNumber]) {
        logger.error("\(errorDict)")
    }

    public func netService(sender: NSNetService, didAcceptConnectionWithInputStream inputStream: NSInputStream, outputStream: NSOutputStream) {
        let client:NetClient = NetClient(service: sender, inputStream: inputStream, outputStream: outputStream)
        clients.append(client)
        client.delegate = self
        client.acceptConnection()
    }
}

// MARK: NetClientDelegate
extension NetService: NetClientDelegate {
}

// MARK: Runnbale 
extension NetService: Runnable {
    final public func startRunning() {
        dispatch_async(lockQueue) {
            if (self.running) {
                return
            }
            self.willStartRunning()
            self.running = true
        }
    }

    final public func stopRunning() {
        dispatch_async(lockQueue) {
            if (!self.running) {
                return
            }
            self.willStopRunning()
            self.running = false
        }
    }
}