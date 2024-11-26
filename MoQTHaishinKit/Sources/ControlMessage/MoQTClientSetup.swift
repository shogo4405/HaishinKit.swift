import Foundation

/// 6.2.  CLIENT_SETUP and SERVER_SETUP
struct MoQTClientSetup: MoQTControlMessage {
    let type: MoQTMessageType = .clientSetup
    let supprtedVersions: [MoQTVersion]
    let setupParameters: [MoQTSetupParameter]

    var payload: Data {
        get throws {
            var payload = MoQTPayload()
            payload.putInt(supprtedVersions.count)
            for version in supprtedVersions {
                payload.putInt(version.rawValue)
            }
            payload.putInt(setupParameters.count)
            for parameter in setupParameters {
                payload.putData(try parameter.payload)
            }
            return payload.data
        }
    }
}

extension MoQTClientSetup {
    init(supportedVersions: [MoQTVersion], role: MoQTSetupRole, path: String?) {
        self.supprtedVersions = supportedVersions
        var setupParameters: [MoQTSetupParameter] = .init()
        setupParameters.append(.init(key: .role, value: role))
        if let path {
            setupParameters.append(.init(key: .path, value: path))
        }
        self.setupParameters = setupParameters
    }
}
