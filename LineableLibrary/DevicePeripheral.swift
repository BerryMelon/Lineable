//
//  DevicePeripheral.swift
//  LineableExample
//
//  Created by Berrymelon on 2/17/16.
//  Copyright © 2016 Lineable. All rights reserved.
//

import Foundation

import CoreBluetooth

class DevicePeripheral:NSObject, CBPeripheralDelegate {
    let serviceUUID:String
    var peripheral:CBPeripheral? = nil {
        didSet(value) {
            self.peripheral?.delegate = self
        }
    }
    var peripheralIdentifier:NSUUID? {
        get {
            if let identifierStr = NSUserDefaults.standardUserDefaults().objectForKey("LineablePeripheralIdentifier_\(serviceUUID)") as? String {
                let uuid = NSUUID(UUIDString: identifierStr)
                return uuid
            }
            else {
                return nil
            }
        }
        set {
            if newValue == nil { return }
            NSUserDefaults.standardUserDefaults().setObject(newValue!.UUIDString, forKey: "LineablePeripheralIdentifier_\(serviceUUID)")
            NSUserDefaults.standardUserDefaults().synchronize()
        }
    }
    
    var didFetchRSSI:((rssi:Int)->())? = nil
    var didUpdateBatteryLevel:((batteryLevel:Double?, rawData:Int?)->())? = nil
    
    init(uuid:String,major:Int,minor:Int) {
        
        let uuidConverter = uuid[0...3] + "0000" + uuid[8...35]
        
        let majorHexString = String(format:"%04X", major)
        let minorHexString = String(format:"%04X", minor)
        
        let serviceUUID = uuidConverter[0...27] + majorHexString + minorHexString
        
        self.serviceUUID = serviceUUID
        super.init()
        
        self.peripheral = LineableBluetoothManager.sharedInstance.knownPeripheralWithIdentifier(self.peripheralIdentifier)
    }
    
    func readRSSI(didFetch:(rssi:Int)->Void) {
        self.didFetchRSSI = didFetch
        
        if self.peripheral != nil && self.peripheral?.state == CBPeripheralState.Connected {
            self.peripheral!.readRSSI()
        }
        else {
            self.didFetchRSSI?(rssi:0)
        }
    }
    
    var soundCharacteristic:CBCharacteristic? = nil
    var LEDCharacteristic:CBCharacteristic? = nil
    var flashCharacteristic:CBCharacteristic? = nil
    var securityCharacteristic:CBCharacteristic? = nil
    var batteryCharacteristic:CBCharacteristic? = nil
    
    let characteristics = [LEDCharUUID,FlashCharUUID,BatteryCharUUID]
    
    var didDiscoverCharacteristics:((characteristics:[CBCharacteristic])->())? = nil
    
    func discoverServices() {
        self.peripheral?.delegate = self
        self.peripheral?.discoverServices([BLEServiceUUID])
    }
    
    //1:connect
    //2:sound
    func playSound(soundType:Int) {
        guard let ledChar = self.soundCharacteristic else { return }
        
        self.peripheral!.readValueForCharacteristic(ledChar)
        self.peripheral!.setNotifyValue(true, forCharacteristic: ledChar)
        
        var score: Int = soundType
        let data = NSData(bytes: &score, length: 1)
        self.peripheral!.writeValue(data, forCharacteristic: ledChar, type: CBCharacteristicWriteType.WithResponse)

    }
    
    func toggleLED() {
        
        guard let ledChar = self.LEDCharacteristic else { return }
        
        self.peripheral!.readValueForCharacteristic(ledChar)
        self.peripheral!.setNotifyValue(true, forCharacteristic: ledChar)
        
        var score: Int = 1
        let data = NSData(bytes: &score, length: 1)
        self.peripheral!.writeValue(data, forCharacteristic: ledChar, type: CBCharacteristicWriteType.WithResponse)
    }
    
    var flashFirmwareCallback:((error:NSError?)->())? = nil
    func flashFirmware(callback:(error:NSError?)->()) {
        
        guard let flashChar = self.flashCharacteristic else { return }
        
        self.flashFirmwareCallback = callback
        
        var score: UInt8 = UInt8(0x01)
        
        self.peripheral!.readValueForCharacteristic(flashChar)
        self.peripheral!.setNotifyValue(true, forCharacteristic: flashChar)
        
        let data = NSData(bytes: &score, length: 1)
        self.peripheral!.writeValue(data, forCharacteristic: flashChar, type: CBCharacteristicWriteType.WithResponse)
    }
    
    private func updateSecurityCode() {
        guard let securityChar = self.securityCharacteristic else { return }
        
        var score: UInt8 = UInt8(0xB8)
        
        self.peripheral!.setNotifyValue(true, forCharacteristic: securityChar)
        
        let data = NSData(bytes: &score, length: 1)
        self.peripheral!.writeValue(data, forCharacteristic: securityChar, type: CBCharacteristicWriteType.WithResponse)
        self.peripheral!.readValueForCharacteristic(securityChar)
    }
    
    func checkBatteryLevel(callback:((batteryLevel:Double?, rawData:Int?)->())?) {
        guard let batteryChar = self.batteryCharacteristic else { return }
        
        var score: UInt8 = UInt8(0x01)
        
        self.peripheral!.setNotifyValue(true, forCharacteristic: batteryChar)
        
        self.didUpdateBatteryLevel = callback
        
        let data = NSData(bytes: &score, length: 1)
        self.peripheral!.writeValue(data, forCharacteristic: batteryChar, type: CBCharacteristicWriteType.WithResponse)
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        
        if (peripheral != self.peripheral) {
            // Wrong Peripheral
            return
        }
        
        if (error != nil) {
            return
        }
        //        0x2A06
        
        if ((peripheral.services == nil) || (peripheral.services!.count == 0)) {
            // No Services
            return
        }
        
        //print("<Lineable> Services")
        for service in peripheral.services! {
            
            if service.UUID == BLEServiceUUID {
                peripheral.discoverCharacteristics(characteristics, forService: service)
            }
            
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didWriteValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        if (peripheral != self.peripheral) {
            // Wrong Peripheral
            return
        }
        if (error != nil) {
            return
        }
        
        self.peripheral!.readValueForCharacteristic(characteristic)
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        if (peripheral != self.peripheral) {
            // Wrong Peripheral
            return
        }
        
        if (error != nil) {
            return
        }
        
        for characteristic in service.characteristics! {
            
            if characteristic.UUID == LEDCharUUID {
                self.LEDCharacteristic = characteristic
                self.soundCharacteristic = characteristic
            }
            
            if characteristic.UUID == FlashCharUUID {
                self.flashCharacteristic = characteristic
                self.securityCharacteristic = characteristic
                self.updateSecurityCode()
                
            }
            
            if characteristic.UUID == BatteryCharUUID {
                self.batteryCharacteristic = characteristic
                self.checkBatteryLevel(self.didUpdateBatteryLevel)
            }
            
        }
        
        self.didDiscoverCharacteristics?(characteristics: service.characteristics!)
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        if error != nil {
            print("Error: \(error?.localizedDescription)")
            return
        }
        
        if characteristic.UUID == BatteryCharUUID {
            //battery level updated
            guard let value = characteristic.value else {
                self.didUpdateBatteryLevel?(batteryLevel: nil, rawData:nil)
                return
            }
            
            var battery = UInt8(0)
            value.getBytes(&battery, range: NSMakeRange(0, 1))
            
            //Limit: BF
            let percentage:Double = 1 - ((227 - Double(battery)) * 1/(227 - 191))
            
            self.didUpdateBatteryLevel?(batteryLevel: percentage, rawData:Int(battery))
            self.didUpdateBatteryLevel = nil
        }
        
        if characteristic.UUID == FlashCharUUID && self.flashFirmwareCallback != nil {
            self.flashFirmwareCallback?(error: error)
            self.flashFirmwareCallback = nil
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: NSError?) {
        self.didFetchRSSI?(rssi:RSSI.integerValue)
    }
    
    func removeSavedData() {
        NSUserDefaults.standardUserDefaults().removeObjectForKey("LineablePeripheralIdentifier_\(serviceUUID)")
        NSUserDefaults.standardUserDefaults().synchronize()
    }
}
