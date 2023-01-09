import AppKit
import Foundation

final class MenuViewController: NSViewController {
    @IBOutlet private weak var tableView: NSTableView! {
        didSet {
        }
    }

    struct Menu {
        let title: String
        let factory: () -> NSViewController
    }

    private let menus: [Menu] = [
        .init(title: "Publish Test", factory: { PublishViewController.getUIViewController() }),
        .init(title: "RTMP Playback Test", factory: { RTMPPlaybackViewController.getUIViewController() })
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        let indexSet = NSIndexSet(index: 0)
        tableView.selectRowIndexes(indexSet as IndexSet, byExtendingSelection: false)
    }
}

extension MenuViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return menus.count
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard tableView.selectedRow != -1 else {
            return
        }
        guard let splitViewController = parent as? NSSplitViewController else {
            return
        }
        splitViewController.splitViewItems[1] = NSSplitViewItem(viewController: menus[tableView.selectedRow].factory())
    }
}

extension MenuViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let identifier = tableColumn?.identifier, let cellView = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView else {
            return nil
        }
        cellView.textField?.stringValue = menus[row].title
        return cellView
    }
}
