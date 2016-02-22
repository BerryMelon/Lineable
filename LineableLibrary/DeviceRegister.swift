//
//  LineableRegister.swift
//  Lineable
//
//  Created by BerryMelon on 1/17/16.
//  Copyright © 2016 Lineable. All rights reserved.
//

import UIKit
import CoreBluetooth

protocol DeviceRegisterDelegate {
    
    func registrationTimeout()
    func errorRegistratingLineable(error:NSError?)
    func bluetoothIsOff()
    func didReadValues(serial:String,vendorID:Int)
    
    func registrationComplete(device:Device)
}

class DeviceRegister: NSObject,CBCentralManagerDelegate,CBPeripheralDelegate {
    
    private var centralManager:CBCentralManager? = nil
    private var connectedPeripheral:CBPeripheral? = nil
    
    private var registrationTimer:NSTimer? = nil
    
    private var uuid:String? = nil
    private var major:Int? = nil
    private var minor:Int? = nil
    
    private var majorminorCharacteristic: CBCharacteristic?
    private var uuidCharacteristic: CBCharacteristic?
    private var rssiCharacteristic: CBCharacteristic?
    private var venderCharacteristic: CBCharacteristic?
    private var securityCharacteristic: CBCharacteristic?
    
    var delegate:DeviceRegisterDelegate? = nil
    
    override init() {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startRegistration(uuid:String, major:Int, minor:Int) {
        
        self.registrationTimer?.invalidate()
        self.registrationTimer = nil
        self.registrationTimer = NSTimer.scheduledTimerWithTimeInterval(30.0, target: self, selector: Selector("timeout"), userInfo: nil, repeats: false)
        
        self.uuid = uuid
        self.major = major
        self.minor = minor
        
        self.scan()
    }
    
    func cancel() {
        if let peripheral = self.connectedPeripheral {
            self.centralManager?.cancelPeripheralConnection(peripheral)
        }
        self.connectedPeripheral = nil
        self.registrationTimer?.invalidate()
        self.registrationTimer = nil
        self.readAllFlag = true
        self.centralManager?.stopScan()
        print("<ADDLINEABLE> cancelling scanning.")
    }
    
    func timeout() {
        self.cancel()
        self.delegate?.registrationTimeout()
    }
    
    private func scan() {

        print("<ADDLINEABLE> will scan for peripheral with services")
        self.centralManager!.scanForPeripheralsWithServices([BLEServiceUUID], options: nil)
    }
    
    func writeValues() {
        guard let _ = self.connectedPeripheral else {
            self.cancel()
            self.delegate?.errorRegistratingLineable(nil)
            return
        }
        
        if self.readedVendorID == Vendor.PairingLineable.rawValue || self.readedVendorID >= 100 {
            self.writeSecurity()
        }
        else {
            self.writeMajorMinor()
        }
        
    }
    
    //MARK:Writers
    private func writeSecurity() {
        if self.securityCharacteristic == nil {
            return
        }
        //184, b8
        
        let securityCode = UInt8(0xB8)
        
        let securityCodes:[UInt8] = [securityCode]

        let data = NSData(bytes: securityCodes, length: 1)
        
        self.connectedPeripheral?.writeValue(data, forCharacteristic: self.securityCharacteristic!, type: CBCharacteristicWriteType.WithResponse)
    }
    
    private func writeMajorMinor() {
        if self.majorminorCharacteristic == nil {
            return
        }
        
        guard let aMajor = self.major, aMinor = self.minor else {
            return
        }
        
        let major:UInt16 = UInt16(aMajor)
        let minor:UInt16 = UInt16(aMinor)
        
        let firstMajor = UInt8((major >> 8) & 0xFF)
        let secondMajor = UInt8(major & 0xFF)
        let firstMinor = UInt8((minor >> 8) & 0xFF)
        let secondMinor = UInt8(minor & 0xFF)
        
        let majorMinor:[UInt8] = [firstMajor,secondMajor,firstMinor,secondMinor]
        let data = NSData(bytes: majorMinor, length: 4)
        print("Data:\(data)")
        
        self.connectedPeripheral?.writeValue(data, forCharacteristic: self.majorminorCharacteristic!, type: CBCharacteristicWriteType.WithResponse)

    }
    
    private func writeUUID() {
        if self.uuidCharacteristic == nil {
            return
        }
        
        guard let uuidStr = self.uuid else {
            return
        }
        
        var beaconUUID = [UInt8](count: 16, repeatedValue: 0)
        var beaconIndex = 0
        for var index = 0; index<16; index++ {
            
            let substring = uuidStr.substringWithRange(Range<String.Index>(start: uuidStr.startIndex.advancedBy(beaconIndex), end: uuidStr.startIndex.advancedBy(beaconIndex+1)))
            if substring == "-" {
                beaconIndex++
            }
            
            let byteString = uuidStr.substringWithRange(Range<String.Index>(start: uuidStr.startIndex.advancedBy(beaconIndex), end: uuidStr.startIndex.advancedBy(beaconIndex+2)))
            let pScanner = NSScanner(string: byteString)
            
            var value:UInt32 = 0
            pScanner.scanHexInt(&value)
            print("Index \(index) UUID in String \(byteString) in hex \(value)")
            beaconUUID[index] = UInt8(value)
            beaconIndex = beaconIndex + 2
        }
        
        let data = NSData(bytes: &beaconUUID, length: 16)
        print("Beacon UUID before save \(data)")
        
        self.connectedPeripheral?.writeValue(data, forCharacteristic: self.uuidCharacteristic!, type: CBCharacteristicWriteType.WithResponse)
    }
    
    private func writeRSSI() {
        if self.rssiCharacteristic == nil {
            return
        }
        
        var rssi:UInt8 = 0xBF
        let data = NSData(bytes:&rssi, length: 1)
        
        self.connectedPeripheral?.writeValue(data, forCharacteristic: self.rssiCharacteristic!, type: CBCharacteristicWriteType.WithResponse)
    }


    //MARK: CentralManagerDelegate
    func centralManagerDidUpdateState(central: CBCentralManager) {
        if central.state != CBCentralManagerState.PoweredOn {
            self.delegate?.bluetoothIsOff()
        }
        
        if central.state == CBCentralManagerState.PoweredOn {
            self.scan()
        }
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        print("<AddChild> Did Discover peripheral: \(peripheral)")
        
        if self.connectedPeripheral == nil || self.connectedPeripheral?.state == CBPeripheralState.Disconnected {
            self.connectedPeripheral = peripheral
            self.centralManager?.connectPeripheral(peripheral, options: nil)
        }
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        print("<AddChild> Did connected to peripheral")
        
        if self.connectedPeripheral == peripheral {
            self.connectedPeripheral?.delegate = self
            //self.connectedPeripheral?.readRSSI()
            self.connectedPeripheral?.discoverServices([BLEServiceUUID])
        }
        // Stop scanning for new devices
        central.stopScan()
    }
    
    //MARK:PeripheralDelegate
    func peripheral(peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: NSError?) {
        if error != nil {
            self.cancel()
            self.delegate?.errorRegistratingLineable(error)
        }
        
        if RSSI.integerValue < -60 {
            self.cancel()
            self.scan()
        }
        
        if self.connectedPeripheral == peripheral {
            self.connectedPeripheral?.discoverServices([BLEServiceUUID])
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        print("<AddChild> Did discover services")
        
        let uuidsForBTService: [CBUUID] = [MajorMinorCharUUID,RssiCharUUID,BeaconUUIDCharUUID,VendorCharUUID,SecurityCharUUID]
        
        if (self.connectedPeripheral != peripheral) {
            // Wrong Peripheral
            return
        }
        
        if (error != nil) {
            self.cancel()
            self.scan()
            return
        }
        
        if ((peripheral.services == nil) || (peripheral.services!.count == 0)) {
            self.cancel()
            self.scan()
            return
        }
        
        for service in peripheral.services! {
            
            print("<AddChild> Now discovering service;")
            if service.UUID == BLEServiceUUID {
                peripheral.discoverCharacteristics(uuidsForBTService, forService: service )
            }
        }
    }

    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        if (peripheral != self.connectedPeripheral) {
            // Wrong Peripheral
            return
        }
        
        if (error != nil) {
            self.cancel()
            self.scan()
            return
        }
        
        for characteristic in service.characteristics! {
            
            print("Did discoverCharacteristic: \(characteristic)")
            peripheral.readValueForCharacteristic(characteristic)
            
            if characteristic.UUID == MajorMinorCharUUID {
                self.majorminorCharacteristic = characteristic
            }
            
            if characteristic.UUID == RssiCharUUID {
                self.rssiCharacteristic = characteristic
            }
            
            if characteristic.UUID == BeaconUUIDCharUUID {
                self.uuidCharacteristic = characteristic
            }
            
            if characteristic.UUID == VendorCharUUID {
                self.venderCharacteristic = characteristic
            }
            
            if characteristic.UUID == SecurityCharUUID {
                self.securityCharacteristic = characteristic
            }
        }
    }
    
    private var readedMajorMinor:String? = nil
    private var readedUUID:String? = nil
    private var readedVendorID:Int? = nil
    private var readAllFlag = true
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        
        if error != nil {
            return
        }
        
        if characteristic.UUID == MajorMinorCharUUID {
            let value = characteristic.value
            
            let majorHexString = value!.hexString[0...3]
            let major = UInt16(strtoul(majorHexString, nil, 16))
            let majorStr = String(format: "%05d",major)
            
            let minorHexString = value!.hexString[4...7]
            let minor = UInt16(strtoul(minorHexString, nil, 16))
            let minorStr = String(format: "%05d",minor)
            
            print("MajorMinorValue:\(majorStr)-\(minorStr)")
            
            self.readedMajorMinor = "\(majorStr)-\(minorStr)"
            
            if self.readAllFlag && self.readedMajorMinor != nil && self.readedUUID != nil && self.readedVendorID != nil {
                self.readAllFlag = false
                let serial = "\(self.readedUUID!)-\(self.readedMajorMinor!)"
                let vendor = self.readedVendorID!
                self.delegate?.didReadValues(serial, vendorID: vendor)
            }
        }
        
        if characteristic.UUID == BeaconUUIDCharUUID {
            let value = characteristic.value
            
            print("UUID:\(value!.hexString)")
            
            let uuidStr: NSMutableString = NSMutableString(string: value!.hexString)
            uuidStr.insertString("-", atIndex: 8)
            uuidStr.insertString("-", atIndex: 13)
            uuidStr.insertString("-", atIndex: 18)
            uuidStr.insertString("-", atIndex: 23)
            
            self.readedUUID = uuidStr as String
            
            if self.readAllFlag && self.readedMajorMinor != nil && self.readedUUID != nil && self.readedVendorID != nil {
                self.readAllFlag = false
                let serial = "\(self.readedUUID!)-\(self.readedMajorMinor!)"
                let vendor = self.readedVendorID!
                self.delegate?.didReadValues(serial, vendorID: vendor)
            }
        }
        
        if characteristic.UUID == VendorCharUUID {
            
            let value = characteristic.value
            let bytes = value!.length
            
            var reversedHexString = ""
            if bytes == 0 {
                reversedHexString = "0059"
            }
            else if bytes == 1 {
                let firstHexString = value!.hexString[0...1]
                reversedHexString = "\(firstHexString)"
            }
            else {
                let firstHexString = value!.hexString[0...1]
                let secondHexString = value!.hexString[2...3]
                reversedHexString = "\(secondHexString)\(firstHexString)"
            }
            
            let vendorID = UInt16(strtoul(reversedHexString, nil, 16))
            
            print("VendorID:\(vendorID)")
            self.readedVendorID = Int(vendorID)
            
            if self.readAllFlag && self.readedMajorMinor != nil && self.readedUUID != nil && self.readedVendorID != nil {
                self.readAllFlag = false
                let serial = "\(self.readedUUID!)-\(self.readedMajorMinor!)"
                let vendor = self.readedVendorID!
                self.delegate?.didReadValues(serial, vendorID: vendor)
            }
        }
        
        if characteristic.UUID == SecurityCharUUID {
            let value = characteristic.value
            print("Security:\(value!.hexString)")
        }
        
    }
    
    func peripheral(peripheral: CBPeripheral, didWriteValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        
        if error != nil {
            return
        }
        
        if characteristic.UUID == SecurityCharUUID {
            print("Did Write Security \(characteristic.value) - \(characteristic.UUID) - error:\(error)")
            self.writeMajorMinor()
        }
        
        if characteristic.UUID == MajorMinorCharUUID {
            print("Did Write Value for Major Minor \(characteristic.value) - \(characteristic.UUID) - error:\(error)")
            self.writeUUID()
        }
        
        if characteristic.UUID == BeaconUUIDCharUUID {
            print("Did Write Value for UUID \(characteristic.value) - \(characteristic.UUID) - error:\(error)")
            self.writeRSSI()
        }
        
        if characteristic.UUID == RssiCharUUID {
            print("Did Write Value for Rssi \(characteristic.value) - \(characteristic.UUID) - error:\(error)")
            self.registrationTimer?.invalidate()
            self.registrationTimer = nil
            
            guard let uuid = self.uuid, major = self.major, minor = self.minor, vendor = self.readedVendorID else {
                self.cancel()
                self.delegate?.errorRegistratingLineable(nil)
                return
            }
            
            let device = Device(uuid: uuid, major: major, minor: minor, vendor: vendor)
            device.devicePeripheral?.peripheral = self.connectedPeripheral
            
            self.delegate?.registrationComplete(device)
            
            self.cancel()
        }
    }


    
}
