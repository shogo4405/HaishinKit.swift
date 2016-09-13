import Foundation

protocol SessionDescriptionConvertible {
     mutating func append(line:String)
}

// MARK: -
struct SessionDescription: SessionDescriptionConvertible {
    var protocolVersionNumber:String = "0"
    var originatorAndSessionIdentifier:String = ""
    var sessionName:String = ""
    var URIOfDescription:String = ""
    var emailAddressWithOptionalNameOfContacts:[String] = []
    var phoneNumberWithOptionalNameOfContacts:[String] = []
    var connectionInformation:String = ""
    var bandwidthInformation:[String] = []
    var sessionAttributes:[String:String] = [:]
    var time:[TimeDescription] = []
    var medias:[MediaDescription] = []

    fileprivate var media:MediaDescription?

    mutating func append(line:String) {
        let character:String = line.substring(to: line.characters.index(line.startIndex, offsetBy: 1))
        if (media != nil && character != "m") {
            media?.append(line: line)
            return
        }
        let value:String = line.substring(from: line.characters.index(line.startIndex, offsetBy: 2))
        switch character {
        case "v":
            protocolVersionNumber = value
        case "o":
            originatorAndSessionIdentifier = value
        case "s":
            sessionName = value
        case "c":
            connectionInformation = value
        case "m":
            if let media:MediaDescription = media {
                medias.append(media)
                break
            }
            media = MediaDescription(mediaNameAndTransportAddress: line)
        case "a":
            let pairs:[String] = value.components(separatedBy: ":")
            sessionAttributes[pairs[0]] = pairs[1]
        default:
            break
        }
    }
}

extension SessionDescription: CustomStringConvertible {
    // MARK: CustomStringConvertible
    var description:String {
        get {
            return Mirror(reflecting: self).description
        }
        set {
            let lines:[String] = newValue.components(separatedBy: "\n")
            for line in lines {
                append(line:line)
            }
            if let media:MediaDescription = media {
                medias.append(media)
                self.media = nil
            }
        }
    }
}

// MARK: -
struct TimeDescription: SessionDescriptionConvertible {
    var timeTheSessionIsActive:String = ""
    var repeatTimes:[String] = []

    init(timeTheSessionIsActive:String) {
        self.timeTheSessionIsActive = timeTheSessionIsActive
    }

    mutating func append(line:String) {
        let value:String = line.substring(from: line.characters.index(line.startIndex, offsetBy: 2))
        switch line.substring(to: line.characters.index(line.startIndex, offsetBy: 1)) {
        case "r":
            repeatTimes.append(value)
        default:
            break
        }
    }
}

// MARK: -
struct MediaDescription: SessionDescriptionConvertible {
    var mediaNameAndTransportAddress:String = ""
    var mediaTitleInformationField:[String] = []
    var connectionInformation:[String] = []
    var bandwidthInformation:[String] = []
    var encryptionKey:[String] = []
    var mediaAttributes:[String:String] = [:]

    init(mediaNameAndTransportAddress: String) {
        self.mediaNameAndTransportAddress = mediaNameAndTransportAddress
    }

    mutating func append(line:String) {
        let value:String = line.substring(from: line.characters.index(line.startIndex, offsetBy: 2))
        switch line.substring(to: line.characters.index(line.startIndex, offsetBy: 1)) {
        case "i":
            mediaTitleInformationField.append(value)
        case "c":
            connectionInformation.append(value)
        case "b":
            bandwidthInformation.append(value)
        case "k":
            encryptionKey.append(value)
        case "a":
            let pairs:[String] = value.components(separatedBy: ":")
            mediaAttributes[pairs[0]] = pairs[1]
        default:
            break
        }
    }
}
