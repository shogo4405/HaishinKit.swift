import AppKit
import Foundation
import HaishinKit
#if canImport(ScreenCaptureKit)
import ScreenCaptureKit
#endif

class SCStreamPublishViewController: NSViewController {
    @IBOutlet private weak var cameraPopUpButton: NSPopUpButton!
    @IBOutlet private weak var urlField: NSTextField!
    @IBOutlet private weak var mthkView: MTHKView!

    private let netStreamSwitcher: NetStreamSwitcher = .init()
    private var stream: NetStream {
        return netStreamSwitcher.stream
    }

    private let lockQueue = DispatchQueue(label: "SCStreamPublishViewController.lock")

    private var _scstream: Any?
    @available(macOS 12.3, *)
    private var scstream: SCStream? {
        get {
            _scstream as? SCStream
        }
        set {
            _scstream = newValue
            Task {
                try? newValue?.addStreamOutput(stream, type: .screen, sampleHandlerQueue: lockQueue)
                if #available(macOS 13.0, *) {
                    try? newValue?.addStreamOutput(stream, type: .audio, sampleHandlerQueue: lockQueue)
                }
                try await newValue?.startCapture()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        urlField.stringValue = Preference.defaultInstance.uri ?? ""
        netStreamSwitcher.uri = Preference.defaultInstance.uri ?? ""
        mthkView?.attachStream(stream)
        if #available(macOS 12.3, *) {
            Task {
                try await SCShareableContent.current.windows.forEach {
                    cameraPopUpButton.addItem(withTitle: $0.owningApplication?.applicationName ?? "")
                }
            }
        }
    }

    @IBAction private func publishOrStop(_ sender: NSButton) {
        // Publish
        if sender.title == "Publish" {
            sender.title = "Stop"
            netStreamSwitcher.open(.ingest)
        } else {
            // Stop
            sender.title = "Publish"
            netStreamSwitcher.close()
        }
    }

    @IBAction private func selectCamera(_ sender: AnyObject) {
        if #available(macOS 12.3, *) {
            Task {
                guard let window = try? await SCShareableContent.current.windows.first(where: { $0.owningApplication?.applicationName == cameraPopUpButton.title }) else {
                    return
                }
                print(window)
                let filter = SCContentFilter(desktopIndependentWindow: window)
                let configuration = SCStreamConfiguration()
                configuration.width = Int(window.frame.width)
                configuration.height = Int(window.frame.height)
                configuration.showsCursor = true
                self.scstream = SCStream(filter: filter, configuration: configuration, delegate: self)
            }
        }
    }
}

extension SCStreamPublishViewController: SCStreamDelegate {
    // MARK: SCStreamDelegate
    func stream(_ stream: SCStream, didStopWithError error: any Error) {
        print(error)
    }
}
