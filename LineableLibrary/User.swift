//
//  User.swift
//  LineableExample
//
//  Created by Berrymelon on 2/17/16.
//  Copyright © 2016 Lineable. All rights reserved.
//

import Foundation

let kSavedUserData = "kSavedUserData"

struct User {
    
    static var me:User? = nil
    
    let id:String
    var password:String
    let seq:Int
    let countryCode:String?
    var name:String?
    let isAuth:Bool?
    let phoneModel:String?
    let phoneNumber:String?
    let phoneType:Int?
    var photoUrl:String?
    let token:String
    
    let appPushID:String?
    
    //FACEBOOK, KAKAOTALK, APP
    let joinPath:String?
    
    let adAccept:String?
    let adEmail:String?
    let adAcceptDate:String?
    
    init (withDic dic:[String:AnyObject]) {
        
        id = dic["id"] as! String
        
        let pwStr = dic["password"] as? String
        password = pwStr != nil ? pwStr! : ""
        seq  = dic["seq"] as! Int
        
        countryCode = dic["countryCode"] as? String
        name = dic["firstName"] as? String
        if let isAuthBool = dic["isAuth"] as? Bool {
            isAuth = isAuthBool
        }
        else {
            if let isAuthStr = dic["isAuth"] as? String {
                isAuth = isAuthStr == "Y" ? true : false
            }
            else {
                isAuth = true
            }
        }
        phoneModel = dic["phoneModel"] as? String
        phoneNumber = dic["phoneNumber"] as? String
        phoneType = dic["phoneType"] as? Int
        photoUrl = dic["photoUrl"] as? String
        
        if let token = dic["token"] as? String {
            self.token = token
        }
        else {
            self.token = "InvalidToken"
        }
        
        joinPath = dic["joinPath"] as? String
        
        appPushID = dic["appPushId"] as? String
        
        adAccept = dic["adAccept"] as? String
        adEmail = dic["email"] as? String
        adAcceptDate = dic["adAcceptDate"] as? String
    }
    
    func save() {
        User.me = self
        self.saveToken()
        self.saveMyProfile()
    }
    
    private func saveToken() {
        NSUserDefaults.standardUserDefaults().setObject(self.token, forKey: "UserToken")
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
    static func fetchUserFromSavedData() throws -> User? {
        
        guard let savedDic = NSUserDefaults.standardUserDefaults().objectForKey(kSavedUserData) as? [String:AnyObject] else {
            return nil
        }
        
        let user = User(withDic: savedDic)
        
        return user
    }
    
    static func removeSavedUser() {
        NSUserDefaults.standardUserDefaults().removeObjectForKey("UserToken")
        NSUserDefaults.standardUserDefaults().removeObjectForKey("DeviceKey")
        NSUserDefaults.standardUserDefaults().removeObjectForKey(kSavedUserData)
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
    static func fetchToken() -> String? {
        
        if let token = NSUserDefaults.standardUserDefaults().objectForKey("UserToken") as? String {
            
            return token
        } else {
            return nil
        }
        
    }
    
    static func fetchDeviceKey() -> String {
        
        if let deviceKey = NSUserDefaults.standardUserDefaults().objectForKey("DeviceKey") as? String {
            
            return deviceKey
        } else {
            return "InvalidDeviceKey"
        }
    }
    
    static func saveDeviceKey(key:String) {
        NSUserDefaults.standardUserDefaults().setObject(key, forKey: "DeviceKey")
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
    static func isMe(seq:Int) -> Bool {
        
        if let user = User.me {
            if user.seq == seq {
                return true
            }
            else {
                return false
            }
        }
        
        return false
    }
    
    func getID() -> String {
        if let joinPath = self.joinPath {
            if joinPath == "FACEBOOK" {
                return "via Facebook"
            }
            if joinPath == "KAKAOTALK" {
                return "via Kakaotalk"
            }
        }
        
        return self.id
    }
    
    private func saveMyProfile() {
        
        NSUserDefaults.standardUserDefaults().removeObjectForKey(kSavedUserData)
        
        var data = [String:AnyObject]()
        
        data["id"] = self.id
        data["password"] = self.password
        data["seq"] = self.seq
        
        data["countryCode"] = self.countryCode
        data["firstName"] = self.name
        data["isAuth"] = self.isAuth != nil && self.isAuth! ? "Y" : "N"
        data["phoneModel"] = self.phoneModel
        data["phoneNumber"] = self.phoneNumber
        data["phoneType"] = self.phoneType
        data["photoUrl"] = self.photoUrl
        
        data["token"] = self.token
        data["joinPath"] = self.joinPath
        
        data["appPushId"] = self.appPushID
        
        data["adAccept"] = self.adAccept
        data["email"] = self.adEmail
        data["adAcceptDate"] = self.adAcceptDate
        
        NSUserDefaults.standardUserDefaults().setObject(data, forKey: kSavedUserData)
        NSUserDefaults.standardUserDefaults().synchronize()
        
        User.me = self
    }
}
