import Foundation

/**
 flash.events.IEventDispatcher for Swift
 */
public protocol IEventDispatcher: class {
    func addEventListener(_ type: Event.Name, selector: Selector, observer: AnyObject?, useCapture: Bool)
    func removeEventListener(_ type: Event.Name, selector: Selector, observer: AnyObject?, useCapture: Bool)
    func dispatch(event: Event)
    func dispatch(_ type: Event.Name, bubbles: Bool, data: Any?)
}

public enum EventPhase: UInt8 {
    case capturing = 0
    case atTarget = 1
    case bubbling = 2
    case dispose = 3
}

// MARK: -
/**
 flash.events.Event for Swift
 */
open class Event {
    public struct Name: RawRepresentable, ExpressibleByStringLiteral {
        // swiftlint:disable nesting
        public typealias RawValue = String
        // swiftlint:disable nesting
        public typealias StringLiteralType = String

        public static let sync: Name = "sync"
        public static let event: Name = "event"
        public static let ioError: Name = "ioError"
        public static let rtmpStatus: Name = "rtmpStatus"

        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(stringLiteral value: String) {
            self.rawValue = value
        }
    }

    public static func from(_ notification: Notification) -> Event {
        guard
            let userInfo: [AnyHashable: Any] = notification.userInfo,
            let event: Event = userInfo["event"] as? Event else {
            return Event(type: .event)
        }
        return event
    }

    open fileprivate(set) var type: Name
    open fileprivate(set) var bubbles: Bool
    open fileprivate(set) var data: Any?
    open fileprivate(set) var target: AnyObject?

    public init(type: Name, bubbles: Bool = false, data: Any? = nil) {
        self.type = type
        self.bubbles = bubbles
        self.data = data
    }
}

extension Event: CustomDebugStringConvertible {
    // MARK: CustomDebugStringConvertible
    public var debugDescription: String {
        Mirror(reflecting: self).debugDescription
    }
}

// MARK: -
/**
 flash.events.EventDispatcher for Swift
 */
open class EventDispatcher: IEventDispatcher {
    private weak var target: AnyObject?

    public init() {
    }

    public init(target: AnyObject) {
        self.target = target
    }

    deinit {
        target = nil
    }

    public func addEventListener(_ type: Event.Name, selector: Selector, observer: AnyObject? = nil, useCapture: Bool = false) {
        NotificationCenter.default.addObserver(
            observer ?? target ?? self, selector: selector, name: Notification.Name(rawValue: "\(type.rawValue)/\(useCapture)"), object: target ?? self
        )
    }

    public func removeEventListener(_ type: Event.Name, selector: Selector, observer: AnyObject? = nil, useCapture: Bool = false) {
        NotificationCenter.default.removeObserver(
            observer ?? target ?? self, name: Notification.Name(rawValue: "\(type.rawValue)/\(useCapture)"), object: target ?? self
        )
    }

    open func dispatch(event: Event) {
        event.target = target ?? self
        NotificationCenter.default.post(
            name: Notification.Name(rawValue: "\(event.type.rawValue)/false"), object: target ?? self, userInfo: ["event": event]
        )
        event.target = nil
    }

    public func dispatch(_ type: Event.Name, bubbles: Bool, data: Any?) {
        dispatch(event: Event(type: type, bubbles: bubbles, data: data))
    }
}
