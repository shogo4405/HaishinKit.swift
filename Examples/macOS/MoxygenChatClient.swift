import HaishinKit
import MoQTHaishinKit

public actor MoxygenChatClient {
    public private(set) var isRunning: Bool = false
    private let uri: String
    private lazy var connection = MoQTConnection(.pubSub)

    public init(_ uri: String) {
        self.uri = uri
    }
}

extension MoxygenChatClient: AsyncRunner {
    public func startRunning() {
        Task {
            do {
                let setUp = try await connection.connect(uri)
                print(try await connection.annouce(["shogo4405/1000/0"], authInfo: "test"))
                print(try await connection.subscribeAnnouces(["shogo4405/1000/0"], authInfo: "test"))
            } catch {
                print(error)
            }
        }
    }

    public func stopRunning() {
        Task {
            await connection.close()
        }
    }
}
