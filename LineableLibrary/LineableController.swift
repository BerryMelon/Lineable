//
//  LineableController.swift
//  LineableExample
//
//  Created by Berrymelon on 2/17/16.
//  Copyright © 2016 Lineable. All rights reserved.
//

import Foundation
import CoreBluetooth
import CoreLocation

let kCentralManagerRestoreIdentifierKey = "com.lineable.cbcentralmanager"
let kLineableDisconnectRequest = "kLineableDisconnectRequest"

protocol LineableControllerDelegate: NSObjectProtocol {
    var lineableSeq:Int? {get set}
    
    //Listening
    func listenedToMyLineables(lineables:[Lineable])
    func listenedToMyLineable(lineable:Lineable)
    
    //Status change
    func lineableBecameAway(lineable:Lineable)
    func lineableBecameSafe(lineable:Lineable)
    
    //Bluetooth States
    func willStartScanningLineable(lineable:Lineable)
    func willStartConnectingLineable(lineable:Lineable)
    func willStartDisconnectingLineable(lineable:Lineable)
    func didConnectLineable(lineable:Lineable)
    func didDisconnectLineable(lineable:Lineable)
    func didFailToConnectLineable(lineable:Lineable,error:NSError?)
    func discoveredCharacteristicsForLineable(lineable:Lineable,characteristics:[CBCharacteristic])
    
    //Other
    func lineableHasLowBattery(lineable:Lineable,batteryLevel:Double)
    
    //CBCentralManager
    func bluetoothStatusChanged(state:CBCentralManagerState)
}

extension LineableControllerDelegate {
    
    //Listening
    func listenedToMyLineables(lineables:[Lineable]) {}
    func listenedToMyLineable(lineable:Lineable) {}
    
    //Status change
    func lineableBecameAway(lineable:Lineable) {}
    func lineableBecameSafe(lineable:Lineable) {}
    
    //Bluetooth States
    func willStartScanningLineable(lineable:Lineable) {}
    func willStartConnectingLineable(lineable:Lineable) {}
    func willStartDisconnectingLineable(lineable:Lineable) {}
    func didConnectLineable(lineable:Lineable) {}
    func didDisconnectLineable(lineable:Lineable) {}
    func didFailToConnectLineable(lineable:Lineable,error:NSError?) {}
    func discoveredCharacteristicsForLineable(lineable:Lineable,characteristics:[CBCharacteristic]) {}
    
    //Other
    func lineableHasLowBattery(lineable:Lineable,batteryLevel:Double) {}
    
    //CBCentralManager
    func bluetoothStatusChanged(state:CBCentralManagerState) {}
}


class LineableController: LineableBluetoothManagerDelegate {
    static let sharedInstance = LineableController()
    var lineables:[Lineable] = [] {
        willSet (value) {
            
            for newLineable in value {
                for oldLineable in self.lineables {
                    if newLineable.seq == oldLineable.seq && newLineable.device.vendor.isPairingAvailable() {
                        newLineable.device.devicePeripheral?.peripheral = oldLineable.device.devicePeripheral?.peripheral
                        newLineable.device.devicePeripheral?.peripheralIdentifier = oldLineable.device.devicePeripheral?.peripheralIdentifier
                        newLineable.device.devicePeripheral?.peripheral?.delegate = nil
                        break
                    }
                }
            }
        }
    }
    internal var delegates:[LineableControllerDelegate] = []
    
    private var regionsListened:[String:Bool] = [String:Bool]()
    
    var helper:MyLineableHelper = MyLineableHelper.sharedHelper
    
    var bluetoothPoweredOn:Bool {
        get {
            return LineableBluetoothManager.sharedInstance.isBluetoothConnected()
        }
    }
    
    private init() {
        if NSUserDefaults.standardUserDefaults().objectForKey("LineableSavedMyChildren") != nil {
            let dicArray = NSUserDefaults.standardUserDefaults().objectForKey("LineableSavedMyChildren") as! [[String:AnyObject]]
            if dicArray.isEmpty { return }
            
            var lineableArray = [Lineable]()
            for dic in dicArray {
                let lineable:Lineable = Lineable(withDic: dic)
                lineableArray.append(lineable)
            }
            
            self.lineables = lineableArray
        }
        
        LineableBluetoothManager.sharedInstance.delegate = self
        self.reconnectToConnectedPeripherals()
    }
    
    func setupLineables(infoArray:[[String:AnyObject]]) {
        
        var lineables = [Lineable]()
        for info in infoArray {
            let lineable = Lineable(withDic: info)
            lineables.append(lineable)
        }
        
        self.lineables.removeAll()
        self.lineables = lineables
        self.save()
    }
    
    func save() {
        var saveDics = [[String:AnyObject]]()
        for lineable in self.lineables {
            saveDics.append(lineable.convertToSaveDic())
        }
        NSUserDefaults.standardUserDefaults().setObject(saveDics, forKey: "LineableSavedMyChildren")
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
    func removeSavedData() {
        NSUserDefaults.standardUserDefaults().removeObjectForKey("LineableSavedMyChildren")
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
    //MARK: - Beacon Stuff
    
    func updateLineables(withListenedBeacons beacons:[CLBeacon]) {
        
        if self.lineables.count == 0 { return }
        
        for lineable in self.lineables {
            lineable.updateDevice(withListenedBeacons: beacons, updated: {
                self.notifyListenedToLineable(lineable)
                self.checkStatus(forLineable: lineable)
            })
        }
        
        self.helper.didListenToBeacons(beacons)

    }
    
    func checkStatus(forLineable lineable:Lineable) {
        if !lineable.alarmOn { return }
        
        let currentStatus = lineable.deviceStatus
        lineable.updateStatus()
        let newStatus = lineable.deviceStatus
        
        if currentStatus == .Away {
            if newStatus == .Safe {
                self.becameSafe(lineable)
            }
        }
        else {
            if newStatus == .Away {
                self.disconnectToLineable(lineable, didDisconnect:nil)
                self.becameAway(lineable)
            }
        }
    }
    
    private func becameAway(lineable:Lineable) {
        lineable.sendLastLocation({(result) in
        })
        self.notifyAway(lineable)
    }
    
    private func becameSafe(lineable:Lineable) {
        lineable.sendLastLocation({(result) in
        })
        self.notifySafe(lineable)
    }
    
    func removeLineable(index:Int) {
        
        guard let lineable = self.lineables.get(index) else { return }

        lineable.alarmOn = false
        lineable.removeSavedData()
        self.disconnectToLineable(lineable, didDisconnect:{ [unowned self] in
            self.lineables.removeAtIndex(index)
        })
        
    }
    
    func removeAllLineables() {
        for lineable in self.lineables {
            lineable.alarmOn = false
            lineable.removeSavedData()
        }
        
        self.lineables.removeAll()
    }
    
    //MARK: - Helpers
    private func lineableOfServiceUUID(uuids:[CBUUID]) -> Lineable? {
        
        for lineable in self.lineables {
            for uuid in uuids {
                let trimmedServiceUUID = lineable.device.devicePeripheral?.serviceUUID
                if uuid.UUIDString == trimmedServiceUUID {
                    return lineable
                }
            }
        }
        
        return nil
    }
    
    private func lineableOfPeripheral(peripheral:CBPeripheral) -> Lineable? {
        
        for lineable in self.lineables {
            
            if lineable.device.devicePeripheral?.peripheral == peripheral {
                return lineable
            }
        }
        
        return nil
    }
    
    func findLineable(seq: Int) -> Lineable? {
        
        for lineable in self.lineables {
            if lineable.seq == seq {
                return lineable
            }
        }
        
        return nil
    }
    
    //MARK: - Connect/Disconnect Requests
    private func reconnectToConnectedPeripherals() {

        for lineable in self.lineables {
            if lineable.device.devicePeripheral != nil {
                if lineable.alarmOn {
                    print("reconnectToConnectedPeripherals: \(lineable.name)")
                    self.connectToLineable(lineable)
                }
                else if lineable.device.devicePeripheral?.peripheral?.state != CBPeripheralState.Disconnected {
                    self.disconnectToLineable(lineable, didDisconnect:nil)
                }
            }
        }
        
    }
    
    private func getUUIDThatNeedScanning() -> [CBUUID] {
        var needsScanning = [CBUUID]()
        for myLineable in self.lineables {
            if myLineable.device.devicePeripheral?.peripheral == nil && myLineable.alarmOn {
                
                if let serviceUUID = myLineable.device.devicePeripheral?.serviceUUID {
                    
                    self.notifyScanningLineable(myLineable)
                    needsScanning.append(CBUUID(string: serviceUUID))
                }
            }
        }
        return needsScanning
    }
    
    func connectToLineable(lineable:Lineable) {
        
        if !lineable.alarmOn { return }
        
        let needsScanning = self.getUUIDThatNeedScanning()
        if !needsScanning.isEmpty {
            LineableBluetoothManager.sharedInstance.scanForLineables(needsScanning)
        }
        
        guard let peripheral = lineable.device.devicePeripheral?.peripheral else { return }
        
        if peripheral.state != CBPeripheralState.Connected && peripheral.state != CBPeripheralState.Connecting {
            self.notifyConnectingLineable(lineable)
            LineableBluetoothManager.sharedInstance.connectPeripheral(peripheral)
        }
    }
    
    func receivedDisconnectRequest(noti:NSNotification) {
        let userInfo:Dictionary<String,Int> = noti.userInfo as! Dictionary<String,Int>
        if let seq = userInfo["seq"] {
            guard let lineable = self.findLineable(seq) else { return }
            self.disconnectToLineable(lineable, didDisconnect: nil)
        }
    }
    
    private var disconnectCallback:(()->())? = nil
    func disconnectToLineable(lineable:Lineable, didDisconnect:(()->())?) {
        guard let peripheral = lineable.device.devicePeripheral?.peripheral else {
            didDisconnect?()
            return
        }
        if peripheral.state != CBPeripheralState.Disconnected {
            self.notifyDisconnectingLineable(lineable)
            LineableBluetoothManager.sharedInstance.disconnectPeripheral(peripheral)
            self.disconnectCallback = didDisconnect
        }
        else {
            didDisconnect?()
        }
    }
    
    // MARK: - LineableBluetoothManagerDelegate
    func bluetoothStatusChanged(state:CBCentralManagerState) {
        if state == CBCentralManagerState.PoweredOff {
            for lineable in self.lineables {
                lineable.alarmOn = false
                lineable.deviceStatus = .Away
                self.disconnectToLineable(lineable, didDisconnect:nil)
            }
        }
        
        self.notifyCentralManagerDidUpdateState(state)
    }
    
    func didDiscoverPeripheralWithServiceUUIDs(peripheral:CBPeripheral, serviceUUIDs:[CBUUID]) {
        if let lineable = lineableOfServiceUUID(serviceUUIDs) {
            
            if lineable.device.devicePeripheral?.peripheral?.state == CBPeripheralState.Connecting || lineable.device.devicePeripheral?.peripheral?.state == CBPeripheralState.Connected {
                //Already has a peripheral that is connecting or connected. ignore
                return
            }
            
            lineable.device.devicePeripheral?.peripheral = peripheral
            
            self.connectToLineable(lineable)
        }
    }
    
    func didConnectPeripheral(peripheral:CBPeripheral) {
        
        if let lineable = self.lineableOfPeripheral(peripheral) {
            
            self.notifyDidConnectLineable(lineable)
            lineable.device.devicePeripheral?.didUpdateBatteryLevel = { (percentage, rawData) in
                guard let percentage = percentage else { return }
                if percentage < 0.0 {
                    self.notifyLowBattery(lineable, batteryLevel: percentage)
                }
            }
            lineable.device.devicePeripheral?.didDiscoverCharacteristics = { (characteristics) in
                self.notifyDiscoveredCharacteristicsForLineable(lineable,characteristics: characteristics)
            }
            lineable.device.devicePeripheral?.discoverServices()
            
            if !lineable.alarmOn {
                self.disconnectToLineable(lineable, didDisconnect:nil)
            }
        }
    }
    
    func didDisconnectPeripheral(peripheral:CBPeripheral) {
        
        if let lineable = self.lineableOfPeripheral(peripheral) {
            
            self.notifyDidDisconnectLineable(lineable)
            
            if lineable.alarmOn {
                self.connectToLineable(lineable)
            }
            
            self.disconnectCallback?()
            self.disconnectCallback = nil
        }
        
        
    }
    
    func didFailToConnectPeripheral(peripheral:CBPeripheral, error:NSError?) {
        if let lineable = self.lineableOfPeripheral(peripheral) {
            
            self.notifyDidFailToConnectLineable(lineable, error: error)
            
            if lineable.alarmOn {
                self.connectToLineable(lineable)
            }
        }
    }
    
    func willRestoreState() {
        
    }

}