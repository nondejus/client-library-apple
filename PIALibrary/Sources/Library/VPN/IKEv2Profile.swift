//
//  IKEv2Profile.swift
//  PIALibrary-iOS
//
//  Created by Jose Antonio Blaya Garcia on 21/01/2019.
//  Copyright © 2020 Private Internet Access, Inc.
//
//  This file is part of the Private Internet Access iOS Client.
//
//  The Private Internet Access iOS Client is free software: you can redistribute it and/or
//  modify it under the terms of the GNU General Public License as published by the Free
//  Software Foundation, either version 3 of the License, or (at your option) any later version.
//
//  The Private Internet Access iOS Client is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
//  or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
//  details.
//
//  You should have received a copy of the GNU General Public License along with the Private
//  Internet Access iOS Client.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation
import NetworkExtension
import SwiftyBeaver

private let log = SwiftyBeaver.self

/// Implementation of `VPNProfile` providing IKEv2 connectivity.
public class IKEv2Profile: NetworkExtensionProfile {
    
    private var currentVPN: NEVPNManager {
        return NEVPNManager.shared()
    }
    
    init() {
    }
    
    // MARK: VPNProfile
    
    /// :nodoc:
    public static var vpnType: String {
        return "IKEv2"
    }
    
    /// :nodoc:
    public static var isTunnel: Bool {
        return false
    }
    
    /// :nodoc:
    public var native: Any? {
        return currentVPN
    }
    
    /// :nodoc:
    public func prepare() {
        currentVPN.loadFromPreferences { (_) in
        }
    }
    
    /// :nodoc:
    public func save(withConfiguration configuration: VPNConfiguration, force: Bool, _ callback: SuccessLibraryCallback?) {
        
        currentVPN.loadFromPreferences { (error) in
            if let error = error {
                callback?(error)
                return
            }
            self.doSave(self.currentVPN, withConfiguration: configuration, force: force, callback)
        }
    }
    
    /// :nodoc:
    public func connect(withConfiguration configuration: VPNConfiguration, _ callback: SuccessLibraryCallback?) {
        save(withConfiguration: configuration, force: true) { (error) in
            if let error = error {
                callback?(error)
                return
            }
            do {
                try self.currentVPN.connection.startVPNTunnel()
                callback?(nil)
            } catch let e {
                callback?(e)
            }
        }
    }
    
    /// :nodoc:
    public func disconnect(_ callback: SuccessLibraryCallback?) {
        currentVPN.loadFromPreferences { (error) in
            if let error = error {
                callback?(error)
                return
            }
            
            // prevent reconnection
            self.currentVPN.isOnDemandEnabled = false

            self.currentVPN.saveToPreferences { (error) in
                if let error = error {
                    self.currentVPN.connection.stopVPNTunnel()
                    callback?(error)
                    return
                }
                self.currentVPN.connection.stopVPNTunnel()
                callback?(nil)
            }
        }
    }
    
    /// :nodoc:
    public func updatePreferences(_ callback: SuccessLibraryCallback?) {
        currentVPN.loadFromPreferences { (error) in
            if let error = error {
                callback?(error)
                return
            }
            
            self.currentVPN.saveToPreferences { (error) in
                if let error = error {
                    callback?(error)
                    return
                }
                callback?(nil)
            }
        }
    }
    
    /// :nodoc:
    public func remove(_ callback: SuccessLibraryCallback?) {
        currentVPN.loadFromPreferences { (error) in
            self.currentVPN.removeFromPreferences(completionHandler: callback)
        }
    }
    
    /// :nodoc:
    public func disable(_ callback: SuccessLibraryCallback?) {
        currentVPN.loadFromPreferences { (error) in
            self.currentVPN.isEnabled = false
            self.currentVPN.isOnDemandEnabled = false
            self.currentVPN.saveToPreferences(completionHandler: callback)
        }
    }
    
    /// :nodoc:
    public func parsedCustomConfiguration(from map: [String: Any]) -> VPNCustomConfiguration? {
        return nil
    }
    
    /// :nodoc:
    public func requestLog(withCustomConfiguration customConfiguration: VPNCustomConfiguration?, _ callback: ((String?, Error?) -> Void)?) {
        callback?(nil, ClientError.unsupported)
    }

    /// :nodoc:
    public func requestDataUsage(withCustomConfiguration customConfiguration: VPNCustomConfiguration?, _ callback: LibraryCallback<Usage>?) {
        callback?(nil, ClientError.unsupported)
    }

    // MARK: NetworkExtensionProfile
    
    /// :nodoc:
    public func generatedProtocol(withConfiguration configuration: VPNConfiguration) -> NEVPNProtocol {
        
        var iKEv2Username = ""
        if let username = Client.providers.accountProvider.currentUser?.credentials.username {
            iKEv2Username = username
        }
        
        let cfg = NEVPNProtocolIKEv2()
        cfg.serverAddress = configuration.server.hostname
        cfg.remoteIdentifier = configuration.server.hostname
        cfg.localIdentifier = iKEv2Username
        cfg.username = iKEv2Username
        cfg.passwordReference = configuration.passwordReference
        
        cfg.authenticationMethod = .none
        cfg.disconnectOnSleep = false
        cfg.useExtendedAuthentication = true
        
        if let encryption = IKEv2EncryptionAlgorithm(rawValue: Client.preferences.ikeV2EncryptionAlgorithm) {
            cfg.ikeSecurityAssociationParameters.encryptionAlgorithm = encryption.networkExtensionValue()
            cfg.childSecurityAssociationParameters.encryptionAlgorithm = encryption.networkExtensionValue()
        }
        if let integrity = IKEv2IntegrityAlgorithm(rawValue: Client.preferences.ikeV2IntegrityAlgorithm) {
            cfg.ikeSecurityAssociationParameters.integrityAlgorithm = integrity.networkExtensionValue()
            cfg.childSecurityAssociationParameters.integrityAlgorithm = integrity.networkExtensionValue()
        }
        
        log.debug("IKEv2 Configuration")
        log.debug("-------------------")
        log.debug(cfg)
        log.debug("-------------------")

        return cfg
    }
}
