import UIKit

final class PreferenceViewController: UIViewController {
    @IBOutlet private weak var urlField: UITextField?
    @IBOutlet private weak var streamNameField: UITextField?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        urlField?.text = Preference.default.uri
        streamNameField?.text = Preference.default.streamName
    }

    @IBAction func on(open: UIButton) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let controller: UIViewController = storyboard.instantiateViewController(withIdentifier: "PopUpLive")
        present(controller, animated: true, completion: nil)
    }
}

extension PreferenceViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if urlField == textField {
            Preference.default.uri = textField.text
        }
        if streamNameField == textField {
            Preference.default.streamName = textField.text
        }
        textField.resignFirstResponder()
        return true
    }
}
