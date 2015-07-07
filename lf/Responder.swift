import Foundation

public class Responder: NSObject {

    private var result:(data:[Any?]) -> Void
    private var status:((data:[Any?]) -> Void)?

    public init (result:(data:[Any?]) -> Void, status:((data:[Any?]) -> Void)?) {
        self.result = result
        self.status = status
    }

    convenience public init (result:(data:[Any?]) -> Void) {
        self.init(result: result, status: nil)
    }

    public func onResult(data:[Any?]) {
        result(data: data)
    }

    public func onStatus(data:[Any?]) {
        status?(data: data)
        status = nil
    }
}