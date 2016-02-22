//
//  Device.swift
//  LineableExample
//
//  Created by Berrymelon on 2/17/16.
//  Copyright © 2016 Lineable. All rights reserved.
//

import Foundation
import CoreLocation

enum Vendor:Int {
    case LineableOriginal = 89
    case JaeilMogic = 10//제일모직
    case LineableOriginal2 = 13
    case MiraeEsset = 20//미래에셋
    case Prospecs = 30
    case Agabang = 40
    case PairingLineable = 50
    case Prospecs2 = 48
    case Dotomm = 49
    case Lineable2 = 100
    case Unknown = 0
    
    func isPairingAvailable() -> Bool {
        
        if self == .PairingLineable || self.rawValue >= Vendor.Lineable2.rawValue {
            return true
        }
        else {
            return false
        }
    }
}

struct Signal {
    var pairedRssi:Int = 0
    var rssi:Int = 0
    var accuracy:Double = 0
    var proximity:CLProximity = CLProximity.Unknown
}

func ==(lhs: CLBeacon, rhs: CLBeacon) -> Bool {
    let lhsBeacon = lhs
    let rhsBeacon = rhs
    
    var shiftedSelfMinor = lhsBeacon.minor.intValue >> 8
    shiftedSelfMinor = shiftedSelfMinor << 8
    
    var shiftedBeaconMinor = rhsBeacon.minor.intValue >> 8
    shiftedBeaconMinor = shiftedBeaconMinor << 8
    
    if lhsBeacon.proximityUUID.UUIDString == rhsBeacon.proximityUUID.UUIDString && lhsBeacon.major == rhsBeacon.major && shiftedSelfMinor == shiftedBeaconMinor {
        return true
    }
    else {
        return false
    }
    
}

func ==(lhs:Device,rhs:Device) -> Bool {
    if lhs.serial == rhs.serial {
        return true
    }
    return false
}

func ==(lhs: Device, rhs: CLBeacon) -> Bool {
    let lhsBeacon = lhs
    let rhsBeacon = rhs
    
    var shiftedSelfMinor = Int32(lhsBeacon.minor) >> 8
    shiftedSelfMinor = shiftedSelfMinor << 8
    
    var shiftedBeaconMinor = rhsBeacon.minor.intValue >> 8
    shiftedBeaconMinor = shiftedBeaconMinor << 8
    
    if lhsBeacon.uuid == rhsBeacon.proximityUUID.UUIDString && lhsBeacon.major == rhsBeacon.major && shiftedSelfMinor == shiftedBeaconMinor {
        return true
    }
    else {
        return false
    }
    
}

class Device:Equatable {
    let serial:String
    let major:Int
    let minor:Int
    let uuid:String
    var vendor:Vendor
    var signal:Signal = Signal()
    var devicePeripheral:DevicePeripheral?
    
    init(uuid:String,major:Int,minor:Int,vendor:Int) {
        
        self.uuid = uuid
        self.major = major
        self.minor = minor
        
        if let vendorType = Vendor(rawValue: vendor) {
            self.vendor = vendorType
        }
        else {
            self.vendor = .Unknown
        }
        
        let majorStr = String(format: "%05d", self.major)
        let minorStr = String(format: "%05d", self.minor)
        self.serial = "\(self.uuid)-\(majorStr)-\(minorStr)"
        
        if self.vendor.isPairingAvailable() {
            self.devicePeripheral = DevicePeripheral(uuid: self.uuid, major: self.major, minor: self.minor)
        }
        else {
            self.devicePeripheral = nil
        }
    }
    
    func listenedToBeacon(beacon:CLBeacon) {
        self.signal.rssi = beacon.rssi
        self.signal.accuracy = beacon.accuracy
        self.signal.proximity = beacon.proximity
    }
    
    func didnotListenToBeacon() {
        self.signal.rssi = 0
        self.signal.accuracy = 0
        self.signal.proximity = .Unknown
    }
    
    func checkPeripheral(didCheck:(updatedRssi:Int)->()) {
        self.devicePeripheral?.readRSSI({(rssi) in
            self.signal.pairedRssi = rssi
            didCheck(updatedRssi:rssi)
        })
    }
    
    func removeSavedData() {        
        self.devicePeripheral?.removeSavedData()
        self.devicePeripheral = nil
    }
    
    func printableDic() -> [String:String] {
        
        if self.vendor.isPairingAvailable() {
            var dic = [String:String]()
            
            let msg = self.signal.pairedRssi == 0 ? "DISCONNECTED" : "CONNECTED"
            
            if self.signal.pairedRssi != 0 {
                dic["signal"] = "Paired: \(self.signal.pairedRssi) // Beacon: \(self.signal.rssi)"
            }
            else {
                dic["signal"] = "XXX. BeaconSignal: \(self.signal.rssi)"
            }
            dic["approximity"] = msg
            
            return dic
        }
        else {
            var dic = [String:String]()
            
            var msg = ""
            switch self.signal.proximity {
            case .Far:
                msg = "FAR"
            case .Immediate:
                msg = "IMMEDIATE"
            case .Near:
                msg = "NEAR"
            case .Unknown:
                msg = "UNKNOWN"
            }
            
            if self.signal.rssi < 0 {
                dic["signal"] = "\(self.signal.rssi) (" + String(format: "%.4f",self.signal.accuracy) + ")"
                dic["approximity"] = msg
            }
            else {
                dic["signal"] = "XXX"
                dic["approximity"] = "XXX"
            }
            
            return dic
        }
        
    }

}