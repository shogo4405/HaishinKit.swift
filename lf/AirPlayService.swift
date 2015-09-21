import UIKit
import Foundation

public class AbstractNetService:NSObject, NSNetServiceDelegate {

    private var domain:String
    private var name:String
    private var port:Int32
    private var type:String

    private var running:Bool = false
    private var service:NSNetService!
    private let lockQueue:dispatch_queue_t = dispatch_queue_create("com.github.shogo4405.lf.AbstractService.lock", DISPATCH_QUEUE_SERIAL)

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
            self.running = false
        }
    }

    public func netService(sender: NSNetService, didAcceptConnectionWithInputStream inputStream: NSInputStream, outputStream: NSOutputStream) {
    }

    public func netService(sender: NSNetService, didNotPublish errorDict: [String : NSNumber]) {
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
}

public class AirTunesService:AbstractNetService {
    static public let type:String = "_raop._tcp"
    static public let defaultPort:Int32 = 6000

    static let ver:String = "220.68"
    static let flags:String = "0x4"
    static let features:String = "0x5A7FFFF7,0x1E"
    static let model:String = "AppleTV3,2"

    public convenience init(domain:String, name:String, port:Int32) {
        self.init(domain:domain, type:AirTunesService.type, name:"AAAAAAAAAAAA@" + name, port:port)
    }

    override func createRecordData() -> NSData? {
        let txtDictionary:[String:NSData] = [
            "txtvers": "1".dataUsingEncoding(NSUTF8StringEncoding)!,
            "ch": "2".dataUsingEncoding(NSUTF8StringEncoding)!,
            "cn": "0,1,2,3".dataUsingEncoding(NSUTF8StringEncoding)!,
            "da": "true".dataUsingEncoding(NSUTF8StringEncoding)!,
            "ek": "1".dataUsingEncoding(NSUTF8StringEncoding)!,
            "et": "0,3,5".dataUsingEncoding(NSUTF8StringEncoding)!,
            "md": "0,1,2".dataUsingEncoding(NSUTF8StringEncoding)!,
            "ft": AirTunesService.features.dataUsingEncoding(NSUTF8StringEncoding)!,
            "pw": "false".dataUsingEncoding(NSUTF8StringEncoding)!,
            "sv": "false".dataUsingEncoding(NSUTF8StringEncoding)!,
            "sr": "44100".dataUsingEncoding(NSUTF8StringEncoding)!,
            "ss": "16".dataUsingEncoding(NSUTF8StringEncoding)!,
            "tp": "UDP".dataUsingEncoding(NSUTF8StringEncoding)!,
            "vn": "65537".dataUsingEncoding(NSUTF8StringEncoding)!,
            "vs": AirTunesService.ver.dataUsingEncoding(NSUTF8StringEncoding)!,
            "am": AirTunesService.model.dataUsingEncoding(NSUTF8StringEncoding)!,
            "sf": AirTunesService.flags.dataUsingEncoding(NSUTF8StringEncoding)!,
        ]
        return NSNetService.dataFromTXTRecordDictionary(txtDictionary)
    }
}

public class AirPlayService:AbstractNetService {
    static public let type:String = "_airplay._tcp"
    static public let defaultPort:Int32 = 8000

    private var airTunesService:AirTunesService?

    public convenience init(domain:String, name:String, port:Int32) {
        self.init(domain:domain, type:AirPlayService.type, name:name, port:port)
    }

    override func onStartRunning() {
        airTunesService = AirTunesService(domain: domain, name: name, port: AirTunesService.defaultPort)
        airTunesService!.onStartRunning()
        super.onStartRunning()
    }

    override func onStopRunning() {
        airTunesService!.onStopRunning()
        airTunesService = nil
        super.onStopRunning()
    }

    override func createRecordData() -> NSData? {
        let uuid:String = UIDevice.currentDevice().identifierForVendor!.UUIDString
        let txtDictionary:[String:NSData] = [
            "deviceid": "AA:AA:AA:AA:AA:AA".dataUsingEncoding(NSUTF8StringEncoding)!,
            "features": AirTunesService.features.dataUsingEncoding(NSUTF8StringEncoding)!,
            "model": AirTunesService.model.dataUsingEncoding(NSUTF8StringEncoding)!,
            "srcvers": AirTunesService.ver.dataUsingEncoding(NSUTF8StringEncoding)!,
            "vv": "2".dataUsingEncoding(NSUTF8StringEncoding)!,
            "pi": uuid.dataUsingEncoding(NSUTF8StringEncoding)!,
            "pw": "0".dataUsingEncoding(NSUTF8StringEncoding)!,
            "protovers": "1.0".dataUsingEncoding(NSUTF8StringEncoding)!
        ]
        return NSNetService.dataFromTXTRecordDictionary(txtDictionary)
    }
}

