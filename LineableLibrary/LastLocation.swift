//
//  LastLocation.swift
//  LineableExample
//
//  Created by Berrymelon on 2/18/16.
//  Copyright © 2016 Lineable. All rights reserved.
//

import Foundation

struct LastLocation {
    let date:NSDate
    let name:String
    let seq:Int
    let latitude:Double?
    let longitude:Double?
    let gainChannel:Int
    let accuracy:Double?
    
    let videoUrl:String?
    
    let hasMeta:Bool
    let floor:Int
    
    init(dic:[String:AnyObject]) {
        
        var locDic = dic
        
        if dic["array"] != nil {
            let dicArr = locDic["array"] as! [[String:AnyObject]]
            if !dicArr.isEmpty {
                locDic = dicArr.first!
            }
        }
        
        seq = locDic["userSeq"] as! Int
        
        if let gainChannel = locDic["gainChannel"] as? String where Int(gainChannel) != nil {
            self.gainChannel = Int(gainChannel)!
        }
        else {
            self.gainChannel = 0
        }
        accuracy = locDic["accuracy"] as? Double
        
        let dateString = locDic["detectedDate"] as! String
        date = NSDate.dateByString(dateString)
        
        self.videoUrl = locDic["videoUrl"] as? String
        
        var metaDic:[String:AnyObject]? = nil
        if let metaDataStr = locDic["meta"] as? String {
            let data: NSData = metaDataStr.dataUsingEncoding(NSUTF8StringEncoding)!
            if let result = try! NSJSONSerialization.JSONObjectWithData(data, options: [])
                as? NSDictionary {
                    metaDic = result as? [String : AnyObject]
            }
        }
        
        if let meta = metaDic,floor = meta["floor"] as? Int, latitude = meta["latitude"] as? Double, longitude = meta["longitude"] as? Double, name = meta["name"] as? String {
            self.hasMeta = true
            self.floor = floor
            self.latitude = latitude
            self.longitude = longitude
            self.name = name
        }
        else {
            self.hasMeta = false
            self.floor = 0
            
            if let latitudeStr = locDic["latitude"] as? String {
                latitude = Double(latitudeStr)
            }
            else {
                latitude = nil
            }
            
            if let longitudeStr = locDic["longitude"] as? String {
                longitude = Double(longitudeStr)
            }
            else {
                longitude = nil
            }
            
            if let name = locDic["userName"] as? String {
                self.name = name
            }
            else {
                self.name = ""
            }
        }
        
    }
    
    func locationIsValid() -> Bool {
        
        guard let lat = self.latitude, lon = self.longitude else { return false }
        
        if lat == 0.0 && lon == 0.0 {
            return false
        }
        else {
            return true
        }
    }
}