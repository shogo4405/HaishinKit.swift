import Foundation
import Logboard
import UIKit

public class ClipboardAppender: LogboardAppender {
    private var data:[String] = []

    public func append(_ logboard:Logboard, level: Logboard.Level, message:String, file:StaticString, function:StaticString, line:Int) {
        paste("[\(level)][\(logboard.identifier)][\(line)]\(function)>\(message)")
    }

    public func append(_ logboard:Logboard, level: Logboard.Level, format:String, arguments:CVarArg, file:StaticString, function:StaticString, line:Int) {
        paste("[\(level)][\(logboard.identifier)][\(line)]\(function)>" + String(format: format, arguments))
    }

    private func paste(_ data:String) {
        if 100 < self.data.count {
            self.data.remove(at: 0)
        }
        self.data.append(data)
        let board = UIPasteboard.general
        board.setValue(self.data.joined(separator: "\r\n"), forPasteboardType: "public.text")
    }
}
