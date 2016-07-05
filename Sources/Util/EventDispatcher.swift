import Foundation

// MARK: IEventDispatcher
/**
 flash.events.IEventDispatcher for Swift
 */
public protocol IEventDispatcher: class {
    func addEventListener(type:String, selector:Selector, observer:AnyObject?, useCapture:Bool)
    func removeEventListener(type:String, selector:Selector, observer:AnyObject?, useCapture:Bool)
    func dispatchEvent(e:Event)
    func dispatchEventWith(type:String, bubbles:Bool, data:Any?)
}

// MARK: - EventPhase
public enum EventPhase: UInt8 {
    case Capturing = 0
    case AtTarget  = 1
    case Bubbling  = 2
    case Dispose   = 3
}

// MARK: -
/**
 flash.events.Event for Swift
 */
public class Event {
    public static let SYNC:String = "sync"
    public static let EVENT:String = "event"
    public static let RTMP_STATUS:String = "rtmpStatus"

    public static func from(notification:NSNotification) -> Event {
        if let userInfo = notification.userInfo {
            if let event:Event = userInfo["event"] as? Event {
                return event
            }
        }
        return Event(type: Event.EVENT)
    }

    public private(set) var type:String
    public private(set) var bubbles:Bool
    public private(set) var data:Any?
    public private(set) var target:AnyObject? = nil

    init(type:String, bubbles:Bool = false, data:Any? = nil) {
        self.type = type
        self.bubbles = bubbles
        self.data = data
    }
}

// MARK: CustomStringConvertible
extension Event: CustomStringConvertible {
    public var description:String {
        return Mirror(reflecting: self).description
    }
}

// MARK: -
/**
 flash.events.EventDispatcher for Swift
 */
public class EventDispatcher: NSObject, IEventDispatcher {

    private var target:AnyObject? = nil

    override public init() {
        super.init()
    }

    public init(target:AnyObject) {
        self.target = target
    }

    deinit {
        target = nil
    }

    public final func addEventListener(type:String, selector:Selector, observer:AnyObject? = nil, useCapture:Bool = false) {
        NSNotificationCenter.defaultCenter().addObserver(
            observer ?? target ?? self, selector: selector, name: "\(type)/\(useCapture)", object: target ?? self
        )
    }

    public final func removeEventListener(type:String, selector:Selector, observer:AnyObject? = nil, useCapture:Bool = false) {
        NSNotificationCenter.defaultCenter().removeObserver(
            observer ?? target ?? self, name: "\(type)/\(useCapture)", object: target ?? self
        )
    }

    public func dispatchEvent(e:Event) {
        e.target = target ?? self
        NSNotificationCenter.defaultCenter().postNotificationName(
            "\(e.type)/false", object: target ?? self, userInfo: ["event": e]
        )
        e.target = nil
    }

    public final func dispatchEventWith(type:String, bubbles:Bool, data:Any?) {
        dispatchEvent(Event(type: type, bubbles: bubbles, data: data))
    }
}
