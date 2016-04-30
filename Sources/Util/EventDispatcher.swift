import Foundation

public protocol IEventDispatcher: class {
    func addEventListener(type:String, selector:Selector)
    func addEventListener(type:String, selector:Selector, observer:AnyObject)
    func addEventListener(type:String, selector:Selector, observer:AnyObject, useCapture:Bool)
    func removeEventListener(type:String, selector:Selector)
    func removeEventListener(type:String, selector:Selector, observer:AnyObject)
    func removeEventListener(type:String, selector:Selector, observer:AnyObject, useCapture:Bool)
    func dispatchEvent(e:Event)
    func dispatchEventWith(type:String, bubbles:Bool, data:Any?)
}

public enum EventPhase:UInt8 {
    case CAPTURING = 0
    case AT_TARGET = 1
    case BUBBLING = 2
    case DISPOSE = 3
}

public class Event:NSObject {
    public static let SYNC:String = "sync"
    public static let RTMP_STATUS:String = "rtmpStatus"

    public static func from(notification:NSNotification) -> Event {
        if let userInfo = notification.userInfo {
            if let event:Event = userInfo["event"] as? Event {
                return event
            }
        }
        return Event(type: "")
    }

    public private(set) var type:String = ""
    public private(set) var bubbles:Bool = false
    public private(set) var data:Any? = nil
    public private(set) var target:AnyObject? = nil

    init(type:String, bubbles:Bool, data:Any?) {
        self.type = type
        self.bubbles = bubbles
        self.data = data
    }

    convenience init(type:String) {
        self.init(type: type, bubbles: false, data: nil)
    }

    convenience init(type:String, bubbles:Bool) {
        self.init(type: type, bubbles: bubbles, data: nil)
    }
}

public class EventDispatcher: NSObject, IEventDispatcher {

    private var target:AnyObject? = nil

    override public init() {
        super.init()
    }

    public init(target:AnyObject) {
        self.target = target
    }

    public final func addEventListener(type:String, selector:Selector) {
        addEventListener(type, selector: selector, observer: target == nil ? self : target!, useCapture: false)
    }

    public final func addEventListener(type:String, selector:Selector, observer:AnyObject) {
        addEventListener(type, selector: selector, observer: observer, useCapture: false)
    }

    public final func addEventListener(type:String, selector:Selector, observer:AnyObject, useCapture:Bool) {
        let name:String = type + "/" + useCapture.description
        let center:NSNotificationCenter = NSNotificationCenter.defaultCenter()
        center.addObserver(observer, selector: selector, name: name, object: self)
    }

    public final func removeEventListener(type:String, selector:Selector) {
        removeEventListener(type, selector: selector, observer: self, useCapture: false)
    }

    public final func removeEventListener(type:String, selector:Selector, observer:AnyObject) {
        removeEventListener(type, selector: selector, observer: observer, useCapture: false)
    }

    public final func removeEventListener(type:String, selector:Selector, observer:AnyObject, useCapture:Bool) {
        let name:String = type + "/" + useCapture.description
        let center:NSNotificationCenter = NSNotificationCenter.defaultCenter()
        center.removeObserver(observer, name: name, object: target == nil ? self : target!)
    }

    public func dispatchEvent(e:Event) {
        e.target = target == nil ? self : target!
        let center:NSNotificationCenter = NSNotificationCenter.defaultCenter()
        let name:String = e.type + "/false"
        center.postNotificationName(name, object: target == nil ? self : target!, userInfo: ["event": e])
        e.target = nil
    }

    public final func dispatchEventWith(type:String, bubbles:Bool, data:Any?) {
        self.dispatchEvent(Event(type: type, bubbles: bubbles, data: data))
    }
}
