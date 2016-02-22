//
//  LineableConstants.swift
//  LineableExample
//
//  Created by Berrymelon on 2/17/16.
//  Copyright © 2016 Lineable. All rights reserved.
//

import CoreBluetooth

let BLEServiceUUID = CBUUID(string: "955A1523-0FE2-F5AA-A094-84B8D4F3E8AD")

let MajorMinorCharUUID = CBUUID(string: "955A1526-0FE2-F5AA-A094-84B8D4F3E8AD")
let RssiCharUUID = CBUUID(string: "955A1525-0FE2-F5AA-A094-84B8D4F3E8AD")
let BeaconUUIDCharUUID = CBUUID(string: "955A1524-0FE2-F5AA-A094-84B8D4F3E8AD")
let VendorCharUUID = CBUUID(string: "955A1527-0FE2-F5AA-A094-84B8D4F3E8AD")
let LEDCharUUID = CBUUID(string: "955A1530-0FE2-F5AA-A094-84B8D4F3E8AD")
let SoundCharUUID = CBUUID(string: "955A1530-0FE2-F5AA-A094-84B8D4F3E8AD")
let FlashCharUUID = CBUUID(string: "955A1529-0FE2-F5AA-A094-84B8D4F3E8AD")
let SecurityCharUUID = CBUUID(string: "955A1529-0FE2-F5AA-A094-84B8D4F3E8AD")
let BatteryCharUUID = CBUUID(string: "955a1531-0fe2-f5aa-a094-84b8d4f3e8ad")

extension CBCharacteristic {
    
    var string:String {
        if self.UUID.UUIDString == BLEServiceUUID.UUIDString {
            return "Ble Service UUID"
        }
        
        if self.UUID.UUIDString == RssiCharUUID.UUIDString {
            return "RSSI"
        }
        
        if self.UUID.UUIDString == BeaconUUIDCharUUID.UUIDString {
            return "UUID"
        }
        
        if self.UUID.UUIDString == VendorCharUUID.UUIDString {
            return "Vendor"
        }
        
        if self.UUID.UUIDString == LEDCharUUID.UUIDString {
            return "LED"
        }
        
        if self.UUID.UUIDString == FlashCharUUID.UUIDString {
            return "Flash"
        }
        
        if self.UUID.UUIDString == SecurityCharUUID.UUIDString {
            return "Security"
        }
        
        if self.UUID.UUIDString == BatteryCharUUID.UUIDString {
            return "Battery"
        }
        
        return self.UUID.UUIDString
    }
    
}