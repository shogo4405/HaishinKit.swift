import AppKit
import Foundation

final class FLVAnalyzerViewController: NSViewController {
    @IBOutlet private weak var tableView: NSTableView! = nil
    @IBOutlet private weak var splitView: NSSplitView! = nil
    @IBOutlet private weak var hexView: NSTextView! = nil

    private var tags: [any FLVTag] = []
    private var reader: FLVReader?

    override func viewDidLoad() {
        super.viewDidLoad()
        (view as? DnDableView)?.delegate = self
    }

    private func readFile(_ string: String?) {
        guard let string: String = string, let url = URL(string: string) else {
            return
        }
        tags.removeAll()
        reader = FLVReader(url: url)
        while true {
            guard let tag = reader?.next() else {
                break
            }
            tags.append(tag)
        }
        tableView.reloadData()
    }
}

extension FLVAnalyzerViewController: NSTableViewDataSource {
    // MARK: NSTableViewDataSource
    func numberOfRows(in tableView: NSTableView) -> Int {
        return tags.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let tag: (any FLVTag) = tags[row]
        switch tableColumn?.title ?? "" {
        case "Type":
            return "\(tag.tagType)"
        case "Codec":
            if let tag: FLVAudioTag = tag as? FLVAudioTag {
                return "\(tag.codec)"
            }
            if let tag: FLVVideoTag = tag as? FLVVideoTag {
                return "\(tag.codec)"
            }
            return ""
        case "DataSize":
            return tag.dataSize
        case "Timestamp":
            return tag.timestamp
        case "TimestampExtended":
            return tag.timestampExtended
        case "Remarks":
            if let tag: FLVVideoTag = tag as? FLVVideoTag {
                return "\(tag.avcPacketType):\(tag.frameType)"
            }
            return ""
        default:
            return ""
        }
    }
}

extension FLVAnalyzerViewController: NSTableViewDelegate {
    // MARK: NSTableViewDelegate
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        guard let data: Data = reader?.getData(tags[row]) else {
            return false
        }
        hexView.string = data.bytes.description
        return true
    }
}

extension FLVAnalyzerViewController: DnDDelegate {
    // MARK: DnDDelegate
    func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        if let board = sender.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray {
            readFile(board[0] as? String)
            return true
        }
        return true
    }
}
