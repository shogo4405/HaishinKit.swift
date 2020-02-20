import VideoToolbox

extension VTMultiPassStorage {
    func close() throws {
        let status = VTMultiPassStorageClose(self)
        guard status == noErr else {
            throw OSError.invoke(function: #function, status: status)
        }
    }
}
