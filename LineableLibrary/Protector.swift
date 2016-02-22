//
//  Protector.swift
//  LineableExample
//
//  Created by Berrymelon on 2/17/16.
//  Copyright © 2016 Lineable. All rights reserved.
//

import Foundation

enum ProtectorRole:String {
    case MainProtector = "P"
    case SubProtector = "S"
    case Unknown = "U"
}

enum ProtectorState:String {
    case Disconnected = "Disconnected"
    case Connected = "Connected"
    case Connecting = "Connecting"
}

struct Protector {
    
    let seq:Int
    
    var appPushId:String
    var photoUrl:String?
    var name:String
    var role:ProtectorRole
    var id:String
    var state:ProtectorState = .Disconnected
    
    init(dic:[String:AnyObject]) {
        
        self.seq = dic["userSeq"] as! Int
        
        self.appPushId = dic["appPushId"] as! String
        self.photoUrl = dic["photoUrl"] as? String
        self.name = dic["name"] as! String
        self.id = dic["userId"] as! String
        let roleStr = dic["role"] as! String
        self.role = roleStr == "P" ? ProtectorRole.MainProtector : ProtectorRole.SubProtector
        
    }
    
    func convertToSaveDic() -> [String:AnyObject] {
        
        var saveDic = [String:AnyObject]()
        
        saveDic["userSeq"] = self.seq
        saveDic["appPushId"] = self.appPushId
        saveDic["name"] = self.name
        saveDic["userId"] = self.id
        saveDic["role"] = self.role.rawValue
        saveDic["photoUrl"] = self.photoUrl
        
        return saveDic
    }

    func isMe() -> Bool {
        guard let user = User.me else { return false }
        
        if self.seq == user.seq {
            return true
        }
        else {
            return false
        }
    }
    
}