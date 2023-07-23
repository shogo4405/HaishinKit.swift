import Foundation

/// The EventDispatcherConvertible interface is in implementation which supports the DOM Event Model.
public protocol EventDispatcherConvertible: AnyObject {
    /// Registers the event listeners on the event target.
    func addEventListener(_ type: Event.Name, selector: Selector, observer: AnyObject?, useCapture: Bool)
    /// Unregister the event listeners on the event target.
    func removeEventListener(_ type: Event.Name, selector: Selector, observer: AnyObject?, useCapture: Bool)
    /// Dispatches the events into the implementations event model.
    func dispatch(event: Event)
    /// Dispatches the events into the implementations event model.
    func dispatch(_ type: Event.Name, bubbles: Bool, data: Any?)
}

// MARK: -
/// The Event interface is used to provide information.
open class Event {
    /// A structure that defines the name of an event.
    public struct Name: RawRepresentable, ExpressibleByStringLiteral {
        // swiftlint:disable:next nesting
        public typealias RawValue = String
        // swiftlint:disable:next nesting
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

    /// The type represents the event name.
    public fileprivate(set) var type: Name

    /// The isBubbles indicates whether ot not an event is a bubbling event.
    public fileprivate(set) var bubbles: Bool

    /// The data indicates the to provide information.
    public fileprivate(set) var data: Any?

    /// The target indicates the [IEventDispatcher].
    public fileprivate(set) var target: AnyObject?

    /// Creates a new event.
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
 * The EventDispatcher interface is in implementation which supports the DOM Event Model.
 */
open class EventDispatcher: EventDispatcherConvertible {
    private weak var target: AnyObject?

    /// Creates a new event dispatcher.
    public init() {
    }

    /// Creates a new event dispatcher to proxy target.
    public init(target: AnyObject) {
        self.target = target
    }

    deinit {
        target = nil
    }

    /// Registers the event listeners on the event target.
    public func addEventListener(_ type: Event.Name, selector: Selector, observer: AnyObject? = nil, useCapture: Bool = false) {
        NotificationCenter.default.addObserver(
            observer ?? target ?? self, selector: selector, name: Notification.Name(rawValue: "\(type.rawValue)/\(useCapture)"), object: target ?? self
        )
    }

    /// Unregister the event listeners on the event target.
    public func removeEventListener(_ type: Event.Name, selector: Selector, observer: AnyObject? = nil, useCapture: Bool = false) {
        NotificationCenter.default.removeObserver(
            observer ?? target ?? self, name: Notification.Name(rawValue: "\(type.rawValue)/\(useCapture)"), object: target ?? self
        )
    }

    /// Dispatches the events into the implementations event model.
    open func dispatch(event: Event) {
        event.target = target ?? self
        NotificationCenter.default.post(
            name: Notification.Name(rawValue: "\(event.type.rawValue)/false"), object: target ?? self, userInfo: ["event": event]
        )
        event.target = nil
    }

    /// Dispatches the events into the implementations event model.
    public func dispatch(_ type: Event.Name, bubbles: Bool, data: Any?) {
        dispatch(event: Event(type: type, bubbles: bubbles, data: data))
    }
}
