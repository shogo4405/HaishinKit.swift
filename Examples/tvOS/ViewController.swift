import HaishinKit
import UIKit

final class ViewController: UIViewController {
    @IBOutlet private weak var lfView: MTHKView!

    var rtmpConnection = RTMPConnection()
    var rtmpStream: RTMPStream!

    override func viewDidLoad() {
        super.viewDidLoad()
        rtmpStream = RTMPStream(connection: rtmpConnection)
        rtmpConnection.addEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
        rtmpConnection.connect(Preference.defaultInstance.uri!)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        lfView?.attachStream(rtmpStream)
    }

    @objc
    func rtmpStatusHandler(_ notification: Notification) {
        let e = Event.from(notification)

        guard
            let data: ASObject = e.data as? ASObject,
            let code: String = data["code"] as? String else {
            return
        }

        switch code {
        case RTMPConnection.Code.connectSuccess.rawValue:
            rtmpStream!.play(Preference.defaultInstance.streamName)
        default:
            break
        }
    }
}
