import Foundation

private let kMemoryUsage_count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<UInt32>.size)

final class MemoryUsage {
    static let MB1 = 1000 * 1000 * 1
    static let MB5 = 1000 * 1000 * 5
    static let MB10 = 1000 * 10000 * 10
    static let MB100 = 1000 * 10000 * 1000

    static let shared = MemoryUsage()

    private let step: Int = 512000000
    private var data: [UnsafeMutablePointer<Int8>] = []

    func toEmpty() {
        let available = available()
        allocateAavailable(available)
    }

    func available() -> Int {
        return os_proc_available_memory()
    }

    func allocate(_ size: Int) {
        let value = UnsafeMutablePointer<Int8>.allocate(capacity: size)
        value.update(repeating: 0, count: size)
        data.append(value)
    }

    private func allocateAavailable(_ size: Int) {
        if step < size {
            for _ in 0..<(size / step) {
                let value = UnsafeMutablePointer<Int8>.allocate(capacity: step)
                value.update(repeating: 0, count: step)
                data.append(value)
            }
            sleep(3)
            allocateAavailable(available())
        } else {
            if MemoryUsage.MB5 < size {
                let value = UnsafeMutablePointer<Int8>.allocate(capacity: size - MemoryUsage.MB10)
                value.update(repeating: 0, count: size - MemoryUsage.MB10)
                data.append(value)
            }
        }
    }
}
