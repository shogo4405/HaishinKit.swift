import UIKit
import Foundation

final class PreferenceViewController: UIViewController {
    @IBOutlet var urlField:UITextField?
    @IBOutlet var streamNameField:UITextField?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        urlField?.text = Preference.defaultInstance.uri
        streamNameField?.text = Preference.defaultInstance.streamName
    }
}

extension PreferenceViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if (urlField == textField) {
            Preference.defaultInstance.uri = textField.text
        }
        if (streamNameField == textField) {
            Preference.defaultInstance.streamName = textField.text
        }
        textField.resignFirstResponder()
        return true
    }
}
