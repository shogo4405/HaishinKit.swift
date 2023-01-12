import AppKit
import Foundation

final class PreferenceViewController: NSViewController {
    @IBOutlet private weak var urlField: NSTextField!
    @IBOutlet private weak var streamNameField: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        urlField.stringValue = Preference.defaultInstance.uri ?? ""
        streamNameField.stringValue = Preference.defaultInstance.streamName ?? ""
    }
}

extension PreferenceViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let textFile = obj.object as? NSTextField else {
            return
        }
        if textFile == urlField {
            Preference.defaultInstance.uri = textFile.stringValue
        }
        if textFile == streamNameField {
            Preference.defaultInstance.streamName = textFile.stringValue
        }
    }
}
