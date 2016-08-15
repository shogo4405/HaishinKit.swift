import Foundation

final class Mutex {

    enum Error: ErrorType {
        case Inval
        case Busy
        case Again
        case Deadlnk
        case Perm
    }

    private let mutex:UnsafeMutablePointer<pthread_mutex_t>
    private let condition:UnsafeMutablePointer<pthread_cond_t>
    private let attribute:UnsafeMutablePointer<pthread_mutexattr_t>

    init() {
        mutex = UnsafeMutablePointer.alloc(sizeof(pthread_mutex_t))
        condition = UnsafeMutablePointer.alloc(sizeof(pthread_cond_t))
        attribute = UnsafeMutablePointer.alloc(sizeof(pthread_mutexattr_t))

        pthread_mutexattr_init(attribute)
        pthread_mutex_init(mutex, attribute)
        pthread_cond_init(condition, nil)
    }

    deinit {
        pthread_cond_destroy(condition)
        pthread_mutexattr_destroy(attribute)
        pthread_mutex_destroy(mutex)
    }

    func lock() throws {
        let result:Int32 = pthread_mutex_trylock(mutex)
        switch result {
        case EBUSY:
            throw Mutex.Error.Busy
        case EINVAL:
            throw Mutex.Error.Inval
        default:
            break
        }
    }

    func unlock() {
        pthread_mutex_unlock(mutex)
    }

    func wait() -> Bool {
        return pthread_cond_wait(condition, mutex) == 0
    }

    func signal() -> Bool {
        return pthread_cond_signal(condition) == 0
    }
}
