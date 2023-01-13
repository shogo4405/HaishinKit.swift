import AppKit
import Foundation
import HaishinKit
#if canImport(ScreenCaptureKit)
import ScreenCaptureKit
#endif

class SCStreamPublishViewController: NSViewController {
    @IBOutlet private weak var cameraPopUpButton: NSPopUpButton!
    @IBOutlet private weak var urlField: NSTextField!

    private var currentStream: NetStream?
    private var rtmpConnection = RTMPConnection()
    private lazy var rtmpStream: RTMPStream = {
        let rtmpStream = RTMPStream(connection: rtmpConnection)
        return rtmpStream
    }()

    private var _stream: Any?

    @available(macOS 12.3, *)
    private var stream: SCStream? {
        get {
            _stream as? SCStream
        }
        set {
            _stream = newValue
            Task {
                try? newValue?.addStreamOutput(rtmpStream, type: .screen, sampleHandlerQueue: DispatchQueue.main)
                if #available(macOS 13.0, *) {
                    try? newValue?.addStreamOutput(rtmpStream, type: .audio, sampleHandlerQueue: DispatchQueue.main)
                }
                try? await newValue?.startCapture()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        urlField.stringValue = Preference.defaultInstance.uri ?? ""
        if #available(macOS 12.3, *) {
            Task {
                try await SCShareableContent.current.windows.forEach {
                    cameraPopUpButton.addItem(withTitle: $0.owningApplication?.applicationName ?? "")
                }
            }
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        currentStream = rtmpStream
    }

    @IBAction private func selectCamera(_ sender: AnyObject) {
        if #available(macOS 12.3, *) {
            Task {
                guard let window = try? await SCShareableContent.current.windows.first(where: { $0.owningApplication?.applicationName == cameraPopUpButton.title }) else {
                    return
                }
                let filter = SCContentFilter(desktopIndependentWindow: window)
                let configuration = SCStreamConfiguration()
                configuration.width = Int(window.frame.width)
                configuration.height = Int(window.frame.height)
                configuration.showsCursor = true
                self.stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
            }
        }
    }

    @IBAction private func publishOrStop(_ sender: NSButton) {
        // Publish
        if sender.title == "Publish" {
            sender.title = "Stop"
            rtmpConnection.addEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
            rtmpConnection.connect(Preference.defaultInstance.uri ?? "")
            return
        }
        // Stop
        sender.title = "Publish"
        rtmpConnection.removeEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
        rtmpConnection.close()
        return
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
            rtmpStream.publish(Preference.defaultInstance.streamName)
        default:
            break
        }
    }
}
