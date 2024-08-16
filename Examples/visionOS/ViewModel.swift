import Foundation
import HaishinKit

final class ViewModel: ObservableObject {
    let maxRetryCount: Int = 5

    private var connection = RTMPConnection()
    @Published var stream: RTMPStream!
    private var retryCount = 0

    func config() {
        stream = RTMPStream(connection: connection)
    }

    func unregisterForPublishEvent() {
        Task {
            try await stream.close()
        }
    }

    func startPlaying() {
        Task {
            do {
                let response = try await connection.connect(Preference.default.uri ?? "")
                try await stream.play(Preference.default.streamName)
            } catch RTMPConnection.Error.requestFailed(let response) {
                logger.warn(response)
            } catch RTMPStream.Error.requestFailed(let response) {
                logger.warn(response)
            } catch {
                logger.warn(error)
            }
        }
    }

    func stopPlaying() {
        Task {
            try await connection.close()
        }
    }
}
