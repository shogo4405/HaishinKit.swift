import Foundation

protocol SessionDescriptionConvertible {
     mutating func appendLine(line:String)
}

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

    private var media:MediaDescription?

    mutating func appendLine(line:String) {
        let character:String = line.substringToIndex(line.startIndex.advancedBy(1))
        if (media != nil && character != "m") {
            media?.appendLine(line)
            return
        }
        let value:String = line.substringFromIndex(line.startIndex.advancedBy(2))
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
            let pairs:[String] = value.componentsSeparatedByString(":")
            sessionAttributes[pairs[0]] = pairs[1]
        default:
            break
        }
    }
}

// MARK: CustomStringConvertible
extension SessionDescription: CustomStringConvertible {
    var description:String {
        get {
            return Mirror(reflecting: self).description
        }
        set {
            let lines:[String] = newValue.componentsSeparatedByString("\n")
            for line in lines {
                appendLine(line)
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

    mutating func appendLine(line:String) {
        let value:String = line.substringFromIndex(line.startIndex.advancedBy(2))
        switch line.substringToIndex(line.startIndex.advancedBy(1)) {
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

    mutating func appendLine(line:String) {
        let value:String = line.substringFromIndex(line.startIndex.advancedBy(2))
        switch line.substringToIndex(line.startIndex.advancedBy(1)) {
        case "i":
            mediaTitleInformationField.append(value)
        case "c":
            connectionInformation.append(value)
        case "b":
            bandwidthInformation.append(value)
        case "k":
            encryptionKey.append(value)
        case "a":
            let pairs:[String] = value.componentsSeparatedByString(":")
            mediaAttributes[pairs[0]] = pairs[1]
        default:
            break
        }
    }
}
