import Foundation
import HaishinKit
import UIKit

final class PlaybackController: UIViewController {
    private static let maxRetryCount: Int = 5

    @IBOutlet private weak var lfView: GLHKView?

    private var rtmpConnection = RTMPConnection()
    private var rtmpStream: RTMPStream!
    private var retryCount: Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        rtmpStream = RTMPStream(connection: rtmpConnection)
    }

    override func viewWillAppear(_ animated: Bool) {
        logger.info("viewWillAppear")
        super.viewWillAppear(animated)
        rtmpStream.addObserver(self, forKeyPath: "currentFPS", options: .new, context: nil)
        lfView?.attachStream(rtmpStream)
    }

    override func viewWillDisappear(_ animated: Bool) {
        logger.info("viewWillDisappear")
        super.viewWillDisappear(animated)
        rtmpStream.removeObserver(self, forKeyPath: "currentFPS")
        rtmpStream.close()
        rtmpStream.dispose()
    }

    @IBAction func didPlaybackButtonTap(_ button: UIButton) {
        if button.isSelected {
            UIApplication.shared.isIdleTimerDisabled = false
            rtmpConnection.close()
            rtmpConnection.removeEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
            rtmpConnection.removeEventListener(.ioError, selector: #selector(rtmpErrorHandler), observer: self)
            button.setTitle("●", for: [])
        } else {
            UIApplication.shared.isIdleTimerDisabled = true
            rtmpConnection.addEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
            rtmpConnection.addEventListener(.ioError, selector: #selector(rtmpErrorHandler), observer: self)
            rtmpConnection.connect(Preference.defaultInstance.uri!)
            button.setTitle("■", for: [])
        }
        button.isSelected.toggle()
    }

    @objc
    private func rtmpStatusHandler(_ notification: Notification) {
        let e = Event.from(notification)
        guard let data: ASObject = e.data as? ASObject, let code: String = data["code"] as? String else {
            return
        }
        logger.info(code)
        switch code {
        case RTMPConnection.Code.connectSuccess.rawValue:
            retryCount = 0
            rtmpStream.play(Preference.defaultInstance.streamName!)
        case RTMPConnection.Code.connectFailed.rawValue, RTMPConnection.Code.connectClosed.rawValue:
            guard retryCount <= PlaybackController.maxRetryCount else {
                return
            }
            Thread.sleep(forTimeInterval: pow(2.0, Double(retryCount)))
            rtmpConnection.connect(Preference.defaultInstance.uri!)
            retryCount += 1
        default:
            break
        }
    }

    @objc
    private func rtmpErrorHandler(_ notification: Notification) {
        logger.error(notification)
        rtmpConnection.connect(Preference.defaultInstance.uri!)
    }

    @objc
    private func didEnterBackground(_ notification: Notification) {
        rtmpStream.receiveVideo = false
    }

    @objc
    private func didBecomeActive(_ notification: Notification) {
        rtmpStream.receiveVideo = true
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if Thread.isMainThread {
            // currentFPSLabel?.text = "\(rtmpStream.currentFPS)"
        }
    }
}
