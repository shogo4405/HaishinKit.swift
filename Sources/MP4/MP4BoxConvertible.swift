import Foundation

protocol MP4BoxConvertible: DataConvertible, CustomXmlStringConvertible {
    var size: UInt32 { get }
    var type: String { get }
    var offset: UInt64 { get set }
    var children: [MP4BoxConvertible] { get }

    init()
    func getBoxes<T>(by name: MP4Box.Name<T>) -> [T]
}

extension MP4BoxConvertible {
    var xmlString: String {
        guard !children.isEmpty else {
            return "<\(type) size=\"\(size)\" offset=\"\(offset)\" />"
        }
        var tags: [String] = []
        for child in children {
            tags.append(child.xmlString)
        }
        return "<\(type) size=\"\(size)\" offset=\"\(offset)\">\(tags.joined())</\(type)>"
    }

    func getBoxes<T>(by name: MP4Box.Name<T>) -> [T] {
        var list: [T] = []
        for child in children {
            if name.rawValue == child.type {
                if let box = child as? T {
                    list.append(box)
                } else {
                    var box = T()
                    box.data = child.data
                    list.append(box)
                }
            }
            if !child.children.isEmpty {
                list += child.getBoxes(by: name)
            }
        }
        return list
    }
}
