import UIKit
import Foundation

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

    final public func netService(sender: NSNetService, didAcceptConnectionWithInputStream inputStream: NSInputStream, outputStream: NSOutputStream) {
        let client:NetServiceClient = NetServiceClient(inputStream: inputStream, outputStream: outputStream)
        client.delegate = self
        clients.append(client)
        client.acceptConnection()
    }

    public func netService(sender: NSNetService, didNotPublish errorDict: [String : NSNumber]) {
        print(errorDict)
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

    func handleEvent(client: NetServiceClient) {
    }
}

public class RAOPService:AbstractNetService {
    static public let type:String = "_raop._tcp"
    static public let defaultPort:Int32 = 5100

    static let ver:String = "220.68"
    static let flags:String = "0x4"
    static let features:String = "0x5A7FFFF7,0x1E"
    static let model:String = "AppleTV3,2"

    var key:String = ""

    public convenience init(domain:String, name:String, port:Int32) {
        self.init(domain:domain, type:RAOPService.type, name:name, port:port)
    }

    override func createRecordData() -> NSData? {
        let txtDictionary:[String:NSData] = [
            "txtvers": "1".dataUsingEncoding(NSUTF8StringEncoding)!,
            "ch": "2".dataUsingEncoding(NSUTF8StringEncoding)!,
            "cn": "0,1,2,3".dataUsingEncoding(NSUTF8StringEncoding)!,
            "da": "true".dataUsingEncoding(NSUTF8StringEncoding)!,
            "et": "0,3,5".dataUsingEncoding(NSUTF8StringEncoding)!,
            "ft": RAOPService.features.dataUsingEncoding(NSUTF8StringEncoding)!,
            "pw": "false".dataUsingEncoding(NSUTF8StringEncoding)!,
            "sv": "false".dataUsingEncoding(NSUTF8StringEncoding)!,
            "sr": "44100".dataUsingEncoding(NSUTF8StringEncoding)!,
            "ss": "16".dataUsingEncoding(NSUTF8StringEncoding)!,
            "tp": "UDP".dataUsingEncoding(NSUTF8StringEncoding)!,
            "md": "0,1,2".dataUsingEncoding(NSUTF8StringEncoding)!,
            "vn": "65537".dataUsingEncoding(NSUTF8StringEncoding)!,
            "vs": RAOPService.ver.dataUsingEncoding(NSUTF8StringEncoding)!,
            "am": RAOPService.model.dataUsingEncoding(NSUTF8StringEncoding)!,
            "sf": RAOPService.flags.dataUsingEncoding(NSUTF8StringEncoding)!,
            "pk": key.dataUsingEncoding(NSUTF8StringEncoding)!
        ]
        return NSNetService.dataFromTXTRecordDictionary(txtDictionary)
    }

    override func handleEvent(client: NetServiceClient) {
        if (client.inputBuffer.isEmpty) {
            return
        }
        let request:HTTPRequest = HTTPRequest()
        request.bytes = client.inputBuffer
    }
}

public class AirService:AbstractNetService {
    static public let type:String = "_airplay._tcp"
    static public let defaultPort:Int32 = 8000

    var key:String {
        return UIDevice.currentDevice().identifierForVendor!.UUIDString
    }

    var deviceid:String = {
        var strings:[String] = ["02"]
        let uuid:String = UIDevice.currentDevice().identifierForVendor!.UUIDString.stringByReplacingOccurrencesOfString("-", withString: "")
        for i in 0..<5 {
            let start:String.Index = uuid.startIndex.advancedBy(i)
            let end:String.Index = start.advancedBy(2)
            strings.append(uuid.substringWithRange(Range(start: start, end: end)))
        }
        return strings.joinWithSeparator(":")
    }()

    private var raopService:RAOPService?

    public convenience init(domain:String, name:String, port:Int32) {
        self.init(domain:domain, type:AirService.type, name:name, port:port)
    }

    override func onStartRunning() {
        raopService = RAOPService(domain: domain, name: deviceid.stringByReplacingOccurrencesOfString(":", withString: "")
 + "@" + name, port: RAOPService.defaultPort)
        raopService!.key = key
        raopService!.onStartRunning()
        super.onStartRunning()
    }

    override func onStopRunning() {
        raopService!.onStopRunning()
        raopService = nil
        super.onStopRunning()
    }

    override func createRecordData() -> NSData? {
        let uuid:String = UIDevice.currentDevice().identifierForVendor!.UUIDString
        
        let txtDictionary:[String:NSData] = [
            "deviceid": deviceid.dataUsingEncoding(NSUTF8StringEncoding)!,
            "features": RAOPService.features.dataUsingEncoding(NSUTF8StringEncoding)!,
            "model": RAOPService.model.dataUsingEncoding(NSUTF8StringEncoding)!,
            "srcvers": RAOPService.ver.dataUsingEncoding(NSUTF8StringEncoding)!,
            "vv": "2".dataUsingEncoding(NSUTF8StringEncoding)!,
            "pi": uuid.dataUsingEncoding(NSUTF8StringEncoding)!,
            "pk": key.dataUsingEncoding(NSUTF8StringEncoding)!,
        ]

        return NSNetService.dataFromTXTRecordDictionary(txtDictionary)
    }

    override func handleEvent(client: NetServiceClient) {
        if (client.inputBuffer.isEmpty) {
            return
        }
        let request:HTTPRequest = HTTPRequest()
        request.bytes = client.inputBuffer
    }
}

