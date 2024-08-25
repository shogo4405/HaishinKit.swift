import AppKit
import Foundation
import HaishinKit
#if canImport(ScreenCaptureKit)
@preconcurrency import ScreenCaptureKit
#endif

class SCStreamPublishViewController: NSViewController {
    @IBOutlet private weak var cameraPopUpButton: NSPopUpButton!
    @IBOutlet private weak var urlField: NSTextField!
    @IBOutlet private weak var mthkView: MTHKView!
    private let netStreamSwitcher: HKStreamSwitcher = .init()
    private let lockQueue = DispatchQueue(label: "SCStreamPublishViewController.lock")
    private var _scstream: Any?

    @available(macOS 12.3, *)
    private var scstream: SCStream? {
        get {
            _scstream as? SCStream
        }
        set {
            _scstream = newValue
            /*
             Task {
             try? newValue?.addStreamOutput(stream, type: .screen, sampleHandlerQueue: lockQueue)
             if #available(macOS 13.0, *) {
             try? newValue?.addStreamOutput(stream, type: .audio, sampleHandlerQueue: lockQueue)
             }
             try await newValue?.startCapture()
             }
             */
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        urlField.stringValue = Preference.default.uri ?? ""
        Task {
            await netStreamSwitcher.setPreference(Preference.default)
            let stream = await netStreamSwitcher.stream
            await stream?.addOutput(mthkView!)
            try await SCShareableContent.current.windows.forEach {
                cameraPopUpButton.addItem(withTitle: $0.owningApplication?.applicationName ?? "")
            }
        }
    }

    @IBAction private func publishOrStop(_ sender: NSButton) {
        Task {
            // Publish
            if sender.title == "Publish" {
                sender.title = "Stop"
                await netStreamSwitcher.open(.ingest)
            } else {
                // Stop
                sender.title = "Publish"
                await netStreamSwitcher.close()
            }
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
    nonisolated func stream(_ stream: SCStream, didStopWithError error: any Error) {
        print(error)
    }
}
