import Foundation

// MARK: - NetService
class NetService: NSObject {

    var recordData:NSData? {
        return nil
    }

    private(set) var domain:String
    private(set) var name:String
    private(set) var port:Int32
    private(set) var type:String
    private(set) var running:Bool = false
    private(set) var clients:[NetClient] = []
    private(set) var service:NSNetService!

    private let lockQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.NetService.lock", DISPATCH_QUEUE_SERIAL
    )

    init(domain:String, type:String, name:String, port:Int32) {
        self.domain = domain
        self.name = name
        self.port = port
        self.type = type
    }

    func willStartRunning() {
        service = NSNetService(domain: domain, type: type, name: name, port: port)
        service.delegate = self
        service.setTXTRecordData(recordData)
        service.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSRunLoopCommonModes)
        service.publishWithOptions(NSNetServiceOptions.ListenForConnections)
    }

    func willStopRunning() {
        service.stop()
        service.delegate = nil
        service.removeFromRunLoop(NSRunLoop.currentRunLoop(), forMode: NSRunLoopCommonModes)
        service = nil
    }
}

// MARK: NSNetServiceDelegate
extension NetService: NSNetServiceDelegate {
    func netService(sender: NSNetService, didNotPublish errorDict: [String : NSNumber]) {
        logger.error("\(errorDict)")
    }

    func netService(sender: NSNetService, didAcceptConnectionWithInputStream inputStream: NSInputStream, outputStream: NSOutputStream) {
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
    final func startRunning() {
        dispatch_sync(lockQueue) {
            if (self.running) {
                return
            }
            self.willStartRunning()
            self.running = true
        }
    }

    final func stopRunning() {
        dispatch_sync(lockQueue) {
            if (!self.running) {
                return
            }
            self.willStopRunning()
            self.clients.removeAll(keepCapacity: true)
            self.running = false
        }
    }
}