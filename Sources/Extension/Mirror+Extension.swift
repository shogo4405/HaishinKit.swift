import Foundation

extension Mirror {
    var debugDescription: String {
        var data: [String] = []

        if let superclassMirror: Mirror = superclassMirror {
            for child in superclassMirror.children {
                guard let label: String = child.label else {
                    continue
                }
                data.append("\(label): \(child.value)")
            }
        }
        for child in children {
            guard let label: String = child.label else {
                continue
            }
            data.append("\(label): \(child.value)")
        }
        return "\(subjectType){\(data.joined(separator: ","))}"
    }
}
