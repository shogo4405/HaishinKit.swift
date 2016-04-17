import Foundation

class HTTPService: NetService {
    static let type:String = "_http._tcp"
    static let defaultPort:Int = 8080

    private(set) var streams:[String: HTTPStream] = [:]

    func client(inputBuffer client:NetClient) {
        print(client.inputBuffer)
    }
}
