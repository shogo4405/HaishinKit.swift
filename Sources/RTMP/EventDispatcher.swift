import Foundation

public protocol EventListener: AnyActor {
    func handleEvent(_ event: Event) async
}

/// The EventDispatcherConvertible interface is in implementation which supports the DOM Event Model.
public protocol EventDispatcherConvertible: AnyActor {
    /// Registers the event listeners on the event target.
    func addEventListener(_ type: Event.Name, listener: some EventListener, useCapture: Bool) async
    /// Unregister the event listeners on the event target.
    func removeEventListener(_ type: Event.Name, listener: some EventListener, useCapture: Bool) async
    /// Dispatches the events into the implementations event model.
    func dispatch(event: Event) async
    /// Dispatches the events into the implementations event model.
    func dispatch(_ type: Event.Name, bubbles: Bool, data: Any?) async
}

// MARK: -
/// The Event interface is used to provide information.
public final class Event {
    /// A structure that defines the name of an event.
    public struct Name: RawRepresentable, ExpressibleByStringLiteral, Sendable {
        // swiftlint:disable:next nesting
        public typealias RawValue = String
        // swiftlint:disable:next nesting
        public typealias StringLiteralType = String

        /// A type name for Sync event.
        public static let sync: Name = "sync"
        /// A type name for Event.
        public static let event: Name = "event"
        /// A type name for IO_Error event.
        public static let ioError: Name = "ioError"
        /// A type name for RTMPStatus event.
        public static let rtmpStatus: Name = "rtmpStatus"

        public let rawValue: String

        /// Create a Event.Name by rawValue.
        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// Create a Event.Name by stringLiteral.
        public init(stringLiteral value: String) {
            self.rawValue = value
        }
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
public actor EventDispatcher: EventDispatcherConvertible {
    private weak var target: (any EventListener)?

    /// Creates a new event dispatcher.
    public init() {
    }

    /// Creates a new event dispatcher to proxy target.
    public init(target: any EventListener) {
        self.target = target
    }

    /// Registers the event listeners on the event target.
    public func addEventListener(_ type: Event.Name, listener: some EventListener, useCapture: Bool = false) async {
    }

    /// Unregister the event listeners on the event target.
    public func removeEventListener(_ type: Event.Name, listener: some EventListener, useCapture: Bool = false) async {
    }

    /// Dispatches the events into the implementations event model.
    public func dispatch(event: Event) async {
        event.target = target ?? self
        event.target = nil
    }

    /// Dispatches the events into the implementations event model.
    public func dispatch(_ type: Event.Name, bubbles: Bool, data: Any?) async {
        await dispatch(event: Event(type: type, bubbles: bubbles, data: data))
    }
}
