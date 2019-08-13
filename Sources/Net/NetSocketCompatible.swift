//
//  NetSocketCompatible.swift
//  HaishinKit iOS
//
//  Created by Yusuke Hata on 2019/08/13.
//  Copyright © 2019 Shogo Endo. All rights reserved.
//

import Foundation

protocol NetSocketCompatible {
    var inputBuffer: Data { get set }
    var timeout: Int { get set }
    var totalBytesIn: Int64 { get }
    var totalBytesOut: Int64 { get }
    var queueBytesOut: Int64 { get }
    var connected: Bool { get }
    var securityLevel: StreamSocketSecurityLevel { get set }
    var qualityOfService: DispatchQoS { get set }
    var timeoutHandler: (() -> Void)? { get set }
    var didSetTotalBytesIn: ((Int64) -> Void)? { get set }
    var didSetTotalBytesOut: ((Int64) -> Void)? { get set }
    var didSetConnected: ((Bool) -> Void)? { get set }

    func initConnection()
    func deinitConnection(isDisconnected: Bool)
    func connect(withName: String, port: Int)
    func close(isDisconnected: Bool)

    @discardableResult
    func doOutput(data: Data, locked: UnsafeMutablePointer<UInt32>?) -> Int
}
