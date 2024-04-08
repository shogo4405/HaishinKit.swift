import Cocoa
import Foundation

protocol DnDDelegate: AnyObject {
    func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation
    func performDragOperation(_ sender: any NSDraggingInfo) -> Bool
}
