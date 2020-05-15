//
//  RTMPConnectionDelegate.swift
//  HaishinKit iOS
//
//  Created by Frank on 2020/5/14.
//  Copyright © 2020 Shogo Endo. All rights reserved.
//

import Foundation

public protocol RTMPConnectionDelegate: class {
    func connectionDidSucceed(_ connection: RTMPConnection)
    func connection(_ connection: RTMPConnection, didDisconnectWith error: RTMPConnection.Error?)
}

public extension RTMPConnectionDelegate {
    func connectionDidSucceed(_ connection: RTMPConnection) {}
    func connection(_ connection: RTMPConnection, didDisconnectWith error: RTMPConnection.Error?) {}
}
