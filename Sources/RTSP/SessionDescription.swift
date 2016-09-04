import Foundation

protocol SessionDescriptionConvertible {
     mutating func append(line:String)
}

// MARK: -
struct SessionDescription: SessionDescriptionConvertible {
    internal var protocolVersionNumber:String = "0"
    internal var originatorAndSessionIdentifier:String = ""
    internal var sessionName:String = ""
    internal var URIOfDescription:String = ""
    internal var emailAddressWithOptionalNameOfContacts:[String] = []
    internal var phoneNumberWithOptionalNameOfContacts:[String] = []
    internal var connectionInformation:String = ""
    internal var bandwidthInformation:[String] = []
    internal var sessionAttributes:[String:String] = [:]
    internal var time:[TimeDescription] = []
    internal var medias:[MediaDescription] = []

    fileprivate var media:MediaDescription?

    mutating internal func append(line:String) {
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
    internal var timeTheSessionIsActive:String = ""
    internal var repeatTimes:[String] = []

    internal init(timeTheSessionIsActive:String) {
        self.timeTheSessionIsActive = timeTheSessionIsActive
    }

    mutating internal func append(line:String) {
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
    internal var mediaNameAndTransportAddress:String = ""
    internal var mediaTitleInformationField:[String] = []
    internal var connectionInformation:[String] = []
    internal var bandwidthInformation:[String] = []
    internal var encryptionKey:[String] = []
    internal var mediaAttributes:[String:String] = [:]

    internal init(mediaNameAndTransportAddress: String) {
        self.mediaNameAndTransportAddress = mediaNameAndTransportAddress
    }

    mutating internal func append(line:String) {
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
