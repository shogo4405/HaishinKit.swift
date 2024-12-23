import Network

@available(iOS 16.0, macOS 13.0, tvOS 16.0, *)
extension NWProtocolQUIC.Options {
    func verifySelfCert() -> NWProtocolQUIC.Options {
        let securityProtocolOptions: sec_protocol_options_t = self.securityProtocolOptions
        sec_protocol_options_set_verify_block(securityProtocolOptions, { (_: sec_protocol_metadata_t, _: sec_trust_t, complete: @escaping sec_protocol_verify_complete_t) in
            complete(true)
        }, .main)
        return self
    }
}
