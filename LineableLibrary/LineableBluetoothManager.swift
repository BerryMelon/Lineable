//
//  LineableBluetoothManager.swift
//  Lineable
//
//  Created by Berrymelon on 2/4/16.
//  Copyright © 2016 Lineable. All rights reserved.
//

import Foundation
import CoreBluetooth

protocol LineableBluetoothManagerDelegate {
    
    func bluetoothStatusChanged(state:CBCentralManagerState)
    
    func didDiscoverPeripheralWithServiceUUIDs(peripheral:CBPeripheral, serviceUUIDs:[CBUUID])
    func didConnectPeripheral(peripheral:CBPeripheral)
    func didDisconnectPeripheral(peripheral:CBPeripheral)
    func didFailToConnectPeripheral(peripheral:CBPeripheral, error:NSError?)
    
    func willRestoreState()
}

class LineableBluetoothManager: NSObject, CBCentralManagerDelegate {
    
    static let sharedInstance = LineableBluetoothManager()
    
    private var bluetoothManager:CBCentralManager? = nil
    
    var delegate:LineableBluetoothManagerDelegate? = nil
    
    private override init() {
        super.init()
        self.bluetoothManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey:true, CBCentralManagerOptionRestoreIdentifierKey:kCentralManagerRestoreIdentifierKey])
        
        NSUserDefaults.standardUserDefaults().removeObjectForKey("LineableBluetoothManagerKnownIdentifiers")
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
    func knownPeripheralWithIdentifier(identifier:NSUUID?) -> CBPeripheral? {
        guard let identifier = identifier else { return nil }
        
        let peripherals = self.bluetoothManager!.retrievePeripheralsWithIdentifiers([identifier])
        
        if peripherals.count == 0 {
            return nil
        }
        
        return peripherals.first
    }
    
    func scanForLineables(uuids:[CBUUID]) {
        self.bluetoothManager!.scanForPeripheralsWithServices(uuids, options: [CBCentralManagerScanOptionAllowDuplicatesKey:NSNumber(bool: true)])
    }
    
    func connectPeripheral(peripheral:CBPeripheral) {
        self.bluetoothManager!.connectPeripheral(peripheral, options: [CBConnectPeripheralOptionNotifyOnConnectionKey:NSNumber(bool: true),
            CBConnectPeripheralOptionNotifyOnDisconnectionKey:NSNumber(bool: true),
            CBConnectPeripheralOptionNotifyOnNotificationKey:NSNumber(bool: true)])
    }
    
    func disconnectPeripheral(peripheral:CBPeripheral) {
        self.bluetoothManager!.cancelPeripheralConnection(peripheral)
    }
    
    func isBluetoothConnected() -> Bool {
        if self.bluetoothManager!.state == CBCentralManagerState.PoweredOn {
            return true
        }
        else {
            return false
        }
    }
    
    // MARK: - CBCentralManagerDelegate
    func centralManagerDidUpdateState(central: CBCentralManager) {
        self.delegate?.bluetoothStatusChanged(central.state)
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        if let cbadvDataServiceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            self.delegate?.didDiscoverPeripheralWithServiceUUIDs(peripheral, serviceUUIDs: cbadvDataServiceUUIDs)
        }
        
        self.bluetoothManager?.stopScan()
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        
        self.delegate?.didConnectPeripheral(peripheral)
    }
    
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        self.delegate?.didDisconnectPeripheral(peripheral)
    }
    
    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        self.delegate?.didFailToConnectPeripheral(peripheral, error: error)
    }
    
    func centralManager(central: CBCentralManager, willRestoreState dict: [String : AnyObject]) {
        
        var knownPeripherals = self.bluetoothManager!.retrieveConnectedPeripheralsWithServices([BLEServiceUUID])
        
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            
            for peripheral in peripherals {
                var hasit = false
                for knownPeripheral in knownPeripherals {
                    if knownPeripheral == peripheral {
                        hasit = true
                        break
                    }
                }
                
                if !hasit {
                    knownPeripherals.append(peripheral)
                }
            }
        }
        
        self.delegate?.willRestoreState()
    }

}