import Foundation

final class Mutex {

    enum Error: Swift.Error {
        case inval
        case busy
        case again
        case deadlnk
        case perm
    }

    private let mutex:UnsafeMutablePointer<pthread_mutex_t>
    private let condition:UnsafeMutablePointer<pthread_cond_t>
    private let attribute:UnsafeMutablePointer<pthread_mutexattr_t>

    internal init() {
        mutex = UnsafeMutablePointer<pthread_mutex_t>.allocate(capacity: MemoryLayout<pthread_mutex_t>.size)
        condition = UnsafeMutablePointer<pthread_cond_t>.allocate(capacity: MemoryLayout<pthread_cond_t>.size)
        attribute = UnsafeMutablePointer<pthread_mutexattr_t>.allocate(capacity: MemoryLayout<pthread_mutexattr_t>.size)

        pthread_mutexattr_init(attribute)
        pthread_mutex_init(mutex, attribute)
        pthread_cond_init(condition, nil)
    }

    deinit {
        pthread_cond_destroy(condition)
        pthread_mutexattr_destroy(attribute)
        pthread_mutex_destroy(mutex)
    }

    internal func lock() throws {
        switch pthread_mutex_trylock(mutex) {
        case EBUSY:
            throw Mutex.Error.busy
        case EINVAL:
            throw Mutex.Error.inval
        default:
            break
        }
    }

    internal func unlock() {
        pthread_mutex_unlock(mutex)
    }

    internal func wait() -> Bool {
        return pthread_cond_wait(condition, mutex) == 0
    }

    internal func signal() -> Bool {
        return pthread_cond_signal(condition) == 0
    }
}
