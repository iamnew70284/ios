//
//  NCEntoToEndInterface.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 03/04/17.
//  Copyright © 2017 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation

class NCEntoToEndInterface : NSObject, OCNetworkingDelegate  {

    
    
    struct e2eMetadata: Codable {
        
        struct metadataKey: Codable {
            
            let metadataKeys: [String: String]
            let version: Int
        }
        
        struct sharingKey: Codable {
            
            let recipient: [String: String]
        }
        
        struct filesKey: Codable {
            
            let initializationVector: String
            let authenticationTag: String
            let metadataKey: Int
            let encrypted: String
        }
        
        let files: [String: filesKey]
        let metadata: metadataKey;
        //let sharing: sharingKey;
    }

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    override init() {
    }
    
    // --------------------------------------------------------------------------------------------
    // MARK: Initialize
    // --------------------------------------------------------------------------------------------
    
    @objc func initEndToEndEncryption() {
        
        // Clear all keys 
        CCUtility.clearAllKeysEnd(toEnd: appDelegate.activeAccount)
        
        let metadataNet: CCMetadataNet = CCMetadataNet.init(account: appDelegate.activeAccount)
        
        metadataNet.action = actionGetEndToEndPublicKeys
        appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
    }
    
    func getPrivateKeyCipher() {
        
        let metadataNet: CCMetadataNet = CCMetadataNet.init(account: appDelegate.activeAccount)
        
        metadataNet.action = actionGetEndToEndPrivateKeyCipher
        appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
    }
    
    func getPublicKeyServer() {
        
        let metadataNet: CCMetadataNet = CCMetadataNet.init(account: appDelegate.activeAccount)
        
        metadataNet.action = actionGetEndToEndServerPublicKey
        appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
    }
    
    // --------------------------------------------------------------------------------------------
    // MARK: Manage PublicKey
    // --------------------------------------------------------------------------------------------
    
    func getEndToEndPublicKeysSuccess(_ metadataNet: CCMetadataNet!) {
    
        CCUtility.setEndToEndPublicKey(appDelegate.activeAccount, publicKey: metadataNet.key)
        
        // Request PrivateKey chiper to Server
        getPrivateKeyCipher()
        
        NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: actionGetEndToEndPublicKeys, note: "E2E PublicKey present on Server and stored to keychain", type: k_activityTypeSuccess, verbose: false, activeUrl: "")
    }
    
    func getEndToEndPublicKeysFailure(_ metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
        
        NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: actionGetEndToEndPublicKeys, note: message as String!, type: k_activityTypeFailure, verbose: false, activeUrl: "")
        
        switch errorCode {
            
        case 400:
            
            appDelegate.messageNotification("E2E publicKey", description: "bad request: unpredictable internal error", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            
        case 404:
            
            guard let csr = NCEndToEndEncryption.sharedManager().createCSR(appDelegate.activeUserID, directoryUser: appDelegate.directoryUser) else {
                
                appDelegate.messageNotification("E2E Csr", description: "Error to create Csr", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
                
                NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: actionGetEndToEndPublicKeys, note: "E2E Error to create Csr", type: k_activityTypeFailure, verbose: false, activeUrl: "")
                
                return
            }
            
            let metadataNet: CCMetadataNet = CCMetadataNet.init(account: appDelegate.activeAccount)
            
            metadataNet.action = actionSignEndToEndPublicKey;
            metadataNet.key = csr;
            
            appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
            
        case 409:
        
            appDelegate.messageNotification("E2E publicKey", description: "forbidden: the user can't access the public keys", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            
        default:
        
            appDelegate.messageNotification("E2E publicKey", description: message as String!, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
        }
    }

    func signEnd(toEndPublicKeySuccess metadataNet: CCMetadataNet!) {

        CCUtility.setEndToEndPublicKey(appDelegate.activeAccount, publicKey: metadataNet.key)
        
        // Request PrivateKey chiper to Server
        getPrivateKeyCipher()
        
        NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: actionSignEndToEndPublicKey, note: "E2E Csr - publicKey sign on Server and stored publicKey locally", type: k_activityTypeFailure, verbose: false, activeUrl: "")
    }

    func signEnd(toEndPublicKeyFailure metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
        
        appDelegate.messageNotification("E2E sign Csr - publicKey", description: message as String!, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
        
        NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: actionSignEndToEndPublicKey, note: message, type: k_activityTypeFailure, verbose: false, activeUrl: "")
    }
    
    func deleteEnd(toEndPublicKeySuccess metadataNet: CCMetadataNet!) {
        appDelegate.messageNotification("E2E delete publicKey", description: "Success", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.success, errorCode: 0)
    }
    
    func deleteEnd(toEndPublicKeyFailure metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
        appDelegate.messageNotification("E2E delete publicKey", description: message, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
    }
    
    // --------------------------------------------------------------------------------------------
    // MARK: Manage PrivateKey
    // --------------------------------------------------------------------------------------------
    
    func getEndToEndPrivateKeyCipherSuccess(_ metadataNet: CCMetadataNet!) {
        
        // request Passphrase
        
        var passphraseTextField: UITextField?
                
        let alertController = UIAlertController(title: NSLocalizedString("_e2e_passphrase_request_title_", comment: ""), message: NSLocalizedString("_e2e_passphrase_request_message_", comment: ""), preferredStyle: .alert)
        
        //TEST
        /*
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            
            let fileURL = dir.appendingPathComponent("privatekey.txt")
            
            //writing
            do {
                try metadataNet.key.write(to: fileURL, atomically: false, encoding: .utf8)
            }
            catch {/* error handling here */}
        }
        */
        //
        
        let ok = UIAlertAction(title: "OK", style: .default, handler: { (action) -> Void in
                            
            let passphrase = passphraseTextField?.text
            
            let publicKey = CCUtility.getEndToEndPublicKey(self.appDelegate.activeAccount)

            guard let privateKey = (NCEndToEndEncryption.sharedManager().decryptPrivateKey(metadataNet.key, passphrase: passphrase, publicKey: publicKey)) else {
                
                self.appDelegate.messageNotification("E2E decrypt privateKey", description: "Error to decrypt Private Key", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: 0)
                
                NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: actionGetEndToEndPrivateKeyCipher, note: "E2E Error to decrypt PrivateKey", type: k_activityTypeFailure, verbose: false, activeUrl: "")
                
                return
            }
            
            // privateKey
            print(privateKey)
            
            // Save to keychain
            CCUtility.setEndToEndPrivateKey(self.appDelegate.activeAccount, privateKey: privateKey)
            CCUtility.setEndToEndPassphrase(self.appDelegate.activeAccount, passphrase:passphrase)
            
            // request publicKey Server()
            self.getPublicKeyServer()
            
            NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: actionGetEndToEndPrivateKeyCipher, note: "E2E PrivateKey present on Server and stored to keychain", type: k_activityTypeSuccess, verbose: false, activeUrl: "")
        })
        
        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { (action) -> Void in
        }
        
        alertController.addAction(ok)
        alertController.addAction(cancel)
        alertController.addTextField { (textField) -> Void in
            passphraseTextField = textField
            passphraseTextField?.placeholder = "Enter passphrase (12 words)"
        }
        
        appDelegate.activeMain.present(alertController, animated: true)
    }
    
    func getEndToEndPrivateKeyCipherFailure(_ metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
        
        NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: actionGetEndToEndPrivateKeyCipher, note: message as String!, type: k_activityTypeFailure, verbose: false, activeUrl: "")
        
        switch errorCode {
            
        case 400:
                
            appDelegate.messageNotification("E2E privateKey", description: "bad request: unpredictable internal error", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            
        case 404:
            
            // message
            let e2ePassphrase = NYMnemonic.generateString(128, language: "english")
            let message = "\n" + NSLocalizedString("_e2e_settings_view_passphrase_", comment: "") + "\n\n" + e2ePassphrase!
            
            let alertController = UIAlertController(title: NSLocalizedString("_e2e_settings_title_", comment: ""), message: NSLocalizedString(message, comment: ""), preferredStyle: .alert)
            
            let OKAction = UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default) { action in
                
                var privateKey : NSString?
                
                guard let privateKeyChiper = NCEndToEndEncryption.sharedManager().encryptPrivateKey(self.appDelegate.activeUserID, directoryUser: self.appDelegate.directoryUser, passphrase: e2ePassphrase, privateKey: &privateKey) else {
                    
                    self.appDelegate.messageNotification("E2E privateKey", description: "Error to create PrivateKey chiper", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
                    
                    NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: actionGetEndToEndPrivateKeyCipher, note: "E2E Error to create PrivateKey chiper", type: k_activityTypeFailure, verbose: false, activeUrl: "")
                    
                    return
                }
                
                let metadataNet: CCMetadataNet = CCMetadataNet.init(account: self.appDelegate.activeAccount)

                metadataNet.action = actionStoreEndToEndPrivateKeyCipher
                metadataNet.key = privateKey! as String
                metadataNet.keyCipher = privateKeyChiper
                metadataNet.password = e2ePassphrase
                    
                self.appDelegate.addNetworkingOperationQueue(self.appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
            }
            
            alertController.addAction(OKAction)
            appDelegate.activeMain.present(alertController, animated: true)
            
        case 409:
            
            appDelegate.messageNotification("E2E privateKey", description: "forbidden: the user can't access the private key", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            
        default:
            
            appDelegate.messageNotification("E2E privateKey", description: message as String!, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
        }
    }
    
    func storeEnd(toEndPrivateKeyCipherSuccess metadataNet: CCMetadataNet!) {
        
        CCUtility.setEndToEndPrivateKey(appDelegate.activeAccount, privateKey: metadataNet.key)
        CCUtility.setEndToEndPassphrase(appDelegate.activeAccount, passphrase:metadataNet.password)
        
        // request publicKey Server()
        self.getPublicKeyServer()
        
        NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: actionStoreEndToEndPrivateKeyCipher, note: "E2E PrivateKey stored on Server and stored locally", type: k_activityTypeSuccess, verbose: false, activeUrl: "")

    }
    
    func storeEnd(toEndPrivateKeyCipherFailure metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
        
        appDelegate.messageNotification("E2E sign privateKey", description: message as String!, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
        
        NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: actionStoreEndToEndPrivateKeyCipher, note: message, type: k_activityTypeFailure, verbose: false, activeUrl: "")
    }
    
    func deleteEnd(toEndPrivateKeySuccess metadataNet: CCMetadataNet!) {
        appDelegate.messageNotification("E2E delete privateKey", description: "Success", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.success, errorCode: 0)
    }
    
    func deleteEnd(toEndPrivateKeyFailure metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
        appDelegate.messageNotification("E2E delete privateKey", description: message, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
    }
    
    // --------------------------------------------------------------------------------------------
    // MARK: Manage Server PublicKey
    // --------------------------------------------------------------------------------------------
    
    func getEndToEndServerPublicKeySuccess(_ metadataNet: CCMetadataNet!) {
        
        CCUtility.setEndToEndPublicKeyServer(appDelegate.activeAccount, publicKey: metadataNet.key)
        
        // All OK Activated flsg on Manage EndToEnd Encryption
        NotificationCenter.default.post(name: Notification.Name("reloadManageEndToEndEncryption"), object: nil)
        
        NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: actionGetEndToEndServerPublicKey, note: "E2E Server PublicKey present on Server and stored to keychain", type: k_activityTypeSuccess, verbose: false, activeUrl: "")
    }
    
    func getEndToEndServerPublicKeyFailure(_ metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
                
        NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: actionGetEndToEndServerPublicKey, note: message as String!, type: k_activityTypeFailure, verbose: false, activeUrl: "")
        
        switch (errorCode) {
            
        case 400:
            
            appDelegate.messageNotification("E2E Server publicKey", description: "bad request: unpredictable internal error", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            
        case 404:
            
            appDelegate.messageNotification("E2E Server publicKey", description: "Server publickey doesn't exists", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            
        case 409:
            appDelegate.messageNotification("E2E Server publicKey", description: "forbidden: the user can't access the Server publickey", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            
        default:
            appDelegate.messageNotification("E2E Server publicKey", description: message as String!, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
        }
    }
    
    // --------------------------------------------------------------------------------------------
    // MARK: Mark/Delete Encrypted Folder
    // --------------------------------------------------------------------------------------------
    
    @objc func markEndToEndFolderEncrypted(_ url: String, fileID: String, token: String?) -> Bool {
        
        var token : NSString? = token as NSString?

        if let error = NCNetworkingSync.sharedManager().lockEnd(toEndFolderEncrypted: appDelegate.activeUser, userID: appDelegate.activeUserID, password: appDelegate.activePassword, url: url , fileID: fileID, token: &token) as NSError? {
            
            appDelegate.messageNotification("_error_", description: error.localizedDescription+" code \(error.code)", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: error.code)
            
            return false
        }
        
        if let error = NCNetworkingSync.sharedManager().markEnd(toEndFolderEncrypted: appDelegate.activeUser, userID: appDelegate.activeUserID, password: appDelegate.activePassword, url: url, fileID: fileID) as NSError? {
            
            appDelegate.messageNotification("_error_", description: error.localizedDescription+" code \(error.code)", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: error.code)
            
            return false
        }
        
        if let error = NCNetworkingSync.sharedManager().unlockEnd(toEndFolderEncrypted: appDelegate.activeUser, userID: appDelegate.activeUserID, password: appDelegate.activePassword, url: url, fileID: fileID, token: token! as String) as NSError? {
            
            appDelegate.messageNotification("_error_", description: error.localizedDescription+" code \(error.code)", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: error.code)
            
            return false
        }
        
        return true
    }
    
    @objc func deletemarkEndToEndFolderEncrypted(_ url: String, fileID: String, token: String?) -> Bool {
        
        var token : NSString? = token as NSString?
        
        if let error = NCNetworkingSync.sharedManager().lockEnd(toEndFolderEncrypted: appDelegate.activeUser, userID: appDelegate.activeUserID, password: appDelegate.activePassword, url: url , fileID: fileID, token: &token) as NSError? {
            
            appDelegate.messageNotification("_error_", description: error.localizedDescription+" code \(error.code)", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: error.code)
            
            return false
        }
        
        if let error = NCNetworkingSync.sharedManager().deletemarkEnd(toEndFolderEncrypted: appDelegate.activeUser, userID: appDelegate.activeUserID, password: appDelegate.activePassword, url: url, fileID: fileID) as NSError? {
            
            appDelegate.messageNotification("_error_", description: error.localizedDescription+" code \(error.code)", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: error.code)
            
            return false
        }
        
        if let error = NCNetworkingSync.sharedManager().unlockEnd(toEndFolderEncrypted: appDelegate.activeUser, userID: appDelegate.activeUserID, password: appDelegate.activePassword, url: url, fileID: fileID, token: token! as String) as NSError? {
            
            appDelegate.messageNotification("_error_", description: error.localizedDescription+" code \(error.code)", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: error.code)
            
            return false
        }
        
        return true
    }
    
    // --------------------------------------------------------------------------------------------
    // MARK: Manage Metadata
    // --------------------------------------------------------------------------------------------
    
    func getEndToEndMetadataSuccess(_ metadataNet: CCMetadataNet!) {
        
        let decoder = JSONDecoder.init()
        let data = metadataNet.encryptedMetadata.data(using: .utf8)
        
        do {
            
            let response = try decoder.decode(e2eMetadata.self, from: data!)
            let files = response.files
            let metadata = response.metadata
            
            for file in files {
                
                let fileNameID = file.key
                let element = file.value as e2eMetadata.filesKey
                
                let iv = element.initializationVector
                let tag = element.authenticationTag
                let encrypted = element.encrypted
                
                let privateKey = CCUtility.getEndToEndPrivateKey(appDelegate.activeAccount)
                
                let x = NCEndToEndEncryption.sharedManager().decryptAsymmetricData(encrypted.data(using: .utf8), privateKey: privateKey)
                
                print(metadata)

            }
            
            print(response)

            
        } catch let error {
            
            appDelegate.messageNotification("_error_", description: "Error in decoding metadata", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: 0)
            
            NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: actionGetEndToEndServerPublicKey, note: error.localizedDescription, type: k_activityTypeSuccess, verbose: false, activeUrl: "")
        }
    }
    
    func getEndToEndMetadataFailure(_ metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
        
        // Unauthorized
        if (errorCode == kOCErrorServerUnauthorized) {
            appDelegate.openLoginView(appDelegate.activeMain, loginType: loginModifyPasswordUser)
        }
        
        if (errorCode != kOCErrorServerUnauthorized) {
            
            appDelegate.messageNotification("_error_", description: message as String!, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
        }
    }
    
    @objc func getEndToEndMetadata(_ metadata: tableMetadata) {
        
        let metadataNet: CCMetadataNet = CCMetadataNet.init(account: appDelegate.activeAccount)
        
        metadataNet.action = actionGetEndToEndMetadata;
        metadataNet.fileID = metadata.fileID;
        
        appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
    }
    
}
