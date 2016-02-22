//
//  Lineable.swift
//  LineableExample
//
//  Created by Berrymelon on 2/17/16.
//  Copyright © 2016 Lineable. All rights reserved.
//

import Foundation
import CoreLocation

enum LineableStatus:String {
    case Unknown = "UNKNOWN"
    case WithMe = "WITHME"
    case WithProtector = "WITHPROTECTOR"
    case WithGateway = "WITHGATEWAY"
    case Connecting = "CONNECTING"
    case AlarmOff = "ALARMOFF"
    case Missing = "MISSING"
    case BluetoothOff = "BLUETOOTHOFF"
}

enum DeviceStatus:String {
    case Safe = "Safe"
    case Away = "Away"
}

func ==(lhs:Lineable,rhs:Lineable) -> Bool {
    if lhs.seq == rhs.seq { return true }
    return false
}

protocol LineableProtocol {
    var seq:Int { get }
    var isMissing:Bool { get set }
    var name:String { get set }
    var description:String? { get set }
    var device:Device { get set }
    var photoUrls:[String] { get set }
    var reportedDate:NSDate? { get set }
    var reporterName:String? { get set }
    var reporterPhoneNumber:String? { get set }
    var protectors:[Protector] { get set }
    var algorithm:Algorithm { get set }
    var deviceStatus:DeviceStatus { get set }
    var alarmOn:Bool { get set }
    
    var lastLocation:LastLocation? { get set }
    var lastLocationUpdatedDate:NSDate? { get set }
    var isCurrentlyFetchingLastLocation:Bool { get set }
    
    func updateStatus()
    func updateProtectorState(protectorSeq:Int,state:ProtectorState)
    func updateDevice(withListenedBeacons beacons:[CLBeacon], updated:()->())
}

extension LineableProtocol {
    func convertToSaveDic() -> [String:AnyObject] {
        
        var saveDic = [String:AnyObject]()
        
        var childDic = [String:AnyObject]()
        
        childDic["seq"] = self.seq
        childDic["firstName"] = self.name
        childDic["age"] = 0
        childDic["description"] = self.description
        childDic["isMissing"] = self.isMissing ? "Y" : "N"
        childDic["photoUrl"] = self.photoUrls[0]
        childDic["detailPhotoUrl1"] = self.photoUrls.get(1)
        childDic["detailPhotoUrl2"] = self.photoUrls.get(2)
        childDic["major"] = "\(self.device.major)"
        childDic["minor"] = "\(self.device.minor)"
        childDic["uuid"] = self.device.uuid
        childDic["serial"] = self.device.serial
        childDic["reporterName"] = self.reporterName
        childDic["reporterPhoneNumber"] = self.reporterPhoneNumber
        childDic["reportedDate"] = self.reportedDate?.formattedWith("yyyyMMddHHmmss")
        childDic["vendorId"] = self.device.vendor.rawValue
        
        var protectorDicArray = [[String:AnyObject]]()
        for protector in self.protectors {
            let protectorDic = protector.convertToSaveDic()
            protectorDicArray.append(protectorDic)
        }
        
        saveDic["child"] = childDic
        saveDic["protectors"] = protectorDicArray
        
        return saveDic
    }

    func removeSavedData() {
        self.device.removeSavedData()
        NSUserDefaults.standardUserDefaults().removeObjectForKey("LineableStatus_\(self.seq)")
        NSUserDefaults.standardUserDefaults().removeObjectForKey("LineableAlarm_\(self.seq)")
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
    private func hasConnectedProtector() -> Bool {
        
        var hasit = false
        
        for protector in self.protectors {
            if protector.state == ProtectorState.Connected && !protector.isMe() {
                hasit = true
                break
            }
        }
        
        return hasit
    }
    
    var status:LineableStatus {
        
        var status:LineableStatus = .Unknown
        
        if self.deviceStatus == .Safe { status = .WithMe }
        else {
            
            if !self.alarmOn {
                status = .AlarmOff
            }
            else {
                status = .Connecting
            }
            
            if !LineableController.sharedInstance.bluetoothPoweredOn {
                status = .BluetoothOff
            }
            
            if self.lastLocation?.gainChannel == 2 {
                let intervalSecond = NSDate().timeIntervalSinceDate(self.lastLocation!.date)
                if intervalSecond <= 300 {
                    status = .WithGateway
                    if self.alarmOn {
                        status = .Connecting
                    }
                }
            }
            
            if self.hasConnectedProtector() {
                status = .WithProtector
            }
            
        }
        
        if self.isMissing {
            status = .Missing
        }
        
        return status
    }

}

class Lineable:Equatable,LineableProtocol,LineableManagementHTTP {
    let seq:Int
    var isMissing:Bool = false
    var name:String
    var description:String?
    var device:Device
    var photoUrls:[String]
    var reportedDate:NSDate?
    var reporterName:String?
    var reporterPhoneNumber:String?
    var protectors:[Protector]
    
    var lastLocation:LastLocation? = nil
    var lastLocationUpdatedDate:NSDate? = nil
    var isCurrentlyFetchingLastLocation:Bool = false
    
    internal var algorithm:Algorithm
    var algorithmDescription:String {
        get {
            return self.algorithm.description
        }
    }
    
    var deviceStatus:DeviceStatus {
        get {
            if NSUserDefaults.standardUserDefaults().objectForKey("LineableStatus_\(self.seq)") != nil {
                return DeviceStatus(rawValue: NSUserDefaults.standardUserDefaults().objectForKey("LineableStatus_\(self.seq)") as! String)!
            }
            else {
                return DeviceStatus.Away
            }
        }
        set (newValue) {
            NSUserDefaults.standardUserDefaults().setObject(newValue.rawValue, forKey: "LineableStatus_\(self.seq)")
            NSUserDefaults.standardUserDefaults().synchronize()
        }
    }
    
    var alarmOn:Bool {
        get {
            return NSUserDefaults.standardUserDefaults().boolForKey("LineableAlarm_\(self.seq)")
        }
        set (newValue) {
            NSUserDefaults.standardUserDefaults().setBool(newValue, forKey: "LineableAlarm_\(self.seq)")
            NSUserDefaults.standardUserDefaults().synchronize()
        }
    }

    init(withDic dic: [String : AnyObject]) {
        
        let childDic = dic["child"] as! [String:AnyObject]
        
        self.seq = childDic["seq"] as! Int
        
        self.name = childDic["firstName"] as! String
        self.description = childDic["description"] as? String
        
        let missingStr = childDic["isMissing"] as! String
        self.isMissing = missingStr == "Y" ? true : false
        
        self.photoUrls = [String]()
        let mainPhoto = childDic["photoUrl"] as! String
        self.photoUrls.append(mainPhoto)
        if let detailPhotoUrl1 = childDic["detailPhotoUrl1"] as? String {
            self.photoUrls.append(detailPhotoUrl1)
        }
        if let detailPhotoUrl2 = childDic["detailPhotoUrl2"] as? String {
            self.photoUrls.append(detailPhotoUrl2)
        }
        
        let majorStr = childDic["major"] as! String
        let major = Int(majorStr)!
        let minorStr = childDic["minor"] as! String
        let minor = Int(minorStr)!
        let uuid = childDic["uuid"] as! String
        let vendor = (childDic["vendorId"] as? Int) == nil ? Vendor.LineableOriginal.rawValue : childDic["vendorId"] as! Int
        self.device = Device(uuid: uuid, major: major, minor: minor, vendor: vendor)
        
        self.reporterName = childDic["reporterName"] as? String
        self.reporterPhoneNumber = childDic["reporterPhoneNumber"] as? String
        if let dateStr = childDic["reportedDate"] as? String {
            self.reportedDate = NSDate.dateByString(dateStr)
        }
        else {
            self.reportedDate = nil
        }
        
        var protectors = [Protector]()
        if let protectorArray = dic["protectors"] as? [[String:AnyObject]] {
            for protectorDic in protectorArray {
                let protector = Protector(dic: protectorDic)
                protectors.append(protector)
            }
        }
        self.protectors = protectors
        
        if self.device.vendor.isPairingAvailable() {
            self.algorithm = PairingAlgorithm()
        }
        else {
            self.algorithm = BeaconAlgorithm()
        }
    }
    
    func updateStatus() {
        self.deviceStatus = self.algorithm.updateStatus(self.deviceStatus, device: self.device)
    }
    
    func updateProtectorState(protectorSeq:Int,state:ProtectorState) {
        
        for index in 0..<self.protectors.count {
            if self.protectors[index].seq == protectorSeq {
                self.protectors[index].state = state
                return
            }
        }
    }
    
    func updateDevice(withListenedBeacons beacons:[CLBeacon], updated:()->()) {
        var hasit = false
        for beacon in beacons {
            if self.device == beacon {
                hasit = true
                self.device.listenedToBeacon(beacon)
                break
            }
        }
        
        if !hasit {
            self.device.didnotListenToBeacon()
        }
        
        if self.device.vendor.isPairingAvailable() {
            self.device.checkPeripheral({ (updatedRssi:Int) in
                self.device.signal.pairedRssi = updatedRssi
                updated()
            })
        }
        else {
            updated()
        }
    }
    
    func protectorWithSeq(protectorSeq:Int) -> Protector? {
        for protector in self.protectors {
            if protector.seq == protectorSeq {
                return protector
            }
        }
        
        return nil
    }
    
    func getLastLocation(completion:(success:Bool)->Void) {
        
        let status = self.status
        if status == .WithMe && User.me != nil && LineableDetector.sharedDetector.lastLocation != nil {
            
            let myLocation = LineableDetector.sharedDetector.lastLocation!
            
            let date = NSUserDefaults.standardUserDefaults().objectForKey("LineableLib_DetectTimeStamp") as! NSDate
            let dateStr = date.formattedWith("yyyyMMddHHmmss")
            
            let dic:[String:AnyObject] = ["userName":User.me!.name!,
                "userSeq":User.me!.seq,
                "latitude":"\(myLocation.coordinate.latitude)",
                "longitude":"\(myLocation.coordinate.longitude)",
                "gainChannel":1,
                "accuracy":myLocation.horizontalAccuracy,
                "detectedDate":dateStr]
            
            self.lastLocation = LastLocation(dic: dic)
            
            completion(success: true)
        }
        else {
            
            //마지막으로 체크한게 30초이내면 체크하지 않는다.
            if let lastLocationUpdated = self.lastLocationUpdatedDate {
                let now = NSDate()
                let intervalSecond = now.timeIntervalSinceDate(lastLocationUpdated)
                if intervalSecond < 30 {
                    completion(success: true)
                    return
                }
            }
            
            if !self.isCurrentlyFetchingLastLocation {
                self.isCurrentlyFetchingLastLocation = true
                self.getLastLocation({(result,info) in
                    self.isCurrentlyFetchingLastLocation = false
                    
                    if info == nil || result != 200 {
                        completion(success: false)
                        return
                    }
                    
                    if result == 200 {
                        print("<\(self.name)> last location updated")
                        self.lastLocationUpdatedDate = NSDate()
                        self.lastLocation = LastLocation(dic: info!)
                        completion(success: true)
                        return
                    }
                })
            }
            
        }
        
    }
    
}

