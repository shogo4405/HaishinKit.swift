import Cocoa
import Foundation

final class DnDableView: NSView {
    weak var delegate: (any DnDDelegate)?

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        let draggedType = NSPasteboard.PasteboardType(kUTTypeURL as String)
        registerForDraggedTypes([draggedType])
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard let delegate else {
            return super.draggingEntered(sender)
        }
        return delegate.draggingEntered(sender)
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        guard let delegate else {
            return super.performDragOperation(sender)
        }
        return delegate.performDragOperation(sender)
    }
}
