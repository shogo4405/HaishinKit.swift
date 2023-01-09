import AppKit
import Foundation
import HaishinKit

final class RTMPPlaybackViewController: NSViewController {
    @IBOutlet private weak var lfView: MTHKView!
    @IBOutlet private weak var urlField: NSTextField!

    private var rtmpConnection = RTMPConnection()
    private lazy var rtmpStream: RTMPStream = {
        let rtmpStream = RTMPStream(connection: rtmpConnection)
        // rtmpStream.addObserver(self, forKeyPath: "currentFPS", options: .new, context: nil)
        lfView.attachStream(rtmpStream)
        return rtmpStream
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        rtmpConnection.addEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
    }

    @IBAction private func didTappedPlayback(_ button: NSButton) {
        if button.title == "Stop" {
            rtmpConnection.close()
            button.title = "Playback"
        } else {
            if let uri = Preference.defaultInstance.uri {
                rtmpConnection.connect(uri)
                button.title = "Stop"
            }
        }
    }

    @objc
    private func rtmpStatusHandler(_ notification: Notification) {
        let e = Event.from(notification)
        guard
            let data: ASObject = e.data as? ASObject,
            let code: String = data["code"] as? String else {
            return
        }
        logger.info(data)
        switch code {
        case RTMPConnection.Code.connectSuccess.rawValue:
            rtmpStream.play(Preference.defaultInstance.streamName)
        default:
            break
        }
    }
}
