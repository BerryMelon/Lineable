//
//  LineableDetector.swift
//  LineableDetector
//
//  Created by Berrymelon on 10/15/15.
//  Copyright © 2015 Lineable. All rights reserved.
//


import Foundation
import UIKit
import CoreLocation
import CoreBluetooth

let kLineableLib_SendLocationTime = 60.0
let kLineableLib_ScanAtStart = false
let kLineableLib_BackgroundMode = true

protocol LineableDetectorDelegate {
    
    func didStartRangingLineables()
    func didStopRangingLineables()
    func didDetectLineables(numberOfLineablesDetected:Int, missingLineable:Lineable?)
}

class LineableDetector: NSObject, CLLocationManagerDelegate, LineableDetectHTTP {
    
    static let sharedDetector = LineableDetector()
    
    var delegate:LineableDetectorDelegate? = nil
    
    let locationManager:CLLocationManager = CLLocationManager()
    
    var lastLocation:CLLocation?
    var lineableRegions = LineableRegions()
    var isTracking = false
    var isPreparingDetection = false
    
    let kListeningTime = 3.0
    
    var listenedBeacons = [CLBeacon]()
    
    var missingLineable:Lineable? = nil
    
    var gateway:Gateway? = nil
    
    private var didListenToAllRegions = false
    private var regionsListened:[String:Bool] = [String:Bool]()
    
    private override init() {
        super.init()
        
        let region = LineableRegions()
        for uuid in region.uuidstrs {
            regionsListened[uuid] = false
        }
        
        locationManager.requestAlwaysAuthorization()
        
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10.0
        locationManager.pausesLocationUpdatesAutomatically = true;
        locationManager.delegate = self
        
        locationManager.startUpdatingLocation()
        
        if kLineableLib_ScanAtStart {
            self.startRanging()
        }
    }
    
    func stopTracking() {
        
        self.isTracking = false
        
        for region in lineableRegions.regions {
            let locationRegion = region as CLRegion
            locationManager.stopMonitoringForRegion(locationRegion)
        }
        
        self.stopRanging()
    }
    
    func startTracking() {
        
        self.isTracking = true
        
        for region in lineableRegions.regions {
            let locationRegion = region as CLRegion
            locationManager.startMonitoringForRegion(locationRegion)
        }
        
        self.startRanging()
    }
    
    private func startRanging() {
        
        var rangingCount = 0
        
        for region in lineableRegions.regions {
            
            if !lineableRegions.isRangingForRegion[region.proximityUUID.UUIDString]! {
                locationManager.startRangingBeaconsInRegion(region)
                lineableRegions.isRangingForRegion[region.proximityUUID.UUIDString] = true
                
                rangingCount++
            }
            
        }
        
        if rangingCount > 0 {
            dispatch_async(dispatch_get_main_queue()) {
                self.delegate?.didStartRangingLineables()
            }
        }
        
    }
    
    private func stopRanging() {
        
        var rangingCount = 0
        
        for region in lineableRegions.regions {
            
            if lineableRegions.isRangingForRegion[region.proximityUUID.UUIDString]! {
                locationManager.stopRangingBeaconsInRegion(region)
                
                lineableRegions.isRangingForRegion[region.proximityUUID.UUIDString] = false
                
                rangingCount++
            }
            
        }
        
        if rangingCount > 0 {
            dispatch_async(dispatch_get_main_queue()) {
                self.delegate?.didStopRangingLineables()
            }
        }
        
    }
    
    func locationManager(manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if kLineableLib_BackgroundMode {
            startRanging()
        }
        
    }
    
    
    func locationManager(manager: CLLocationManager, didExitRegion region: CLRegion) {
        if kLineableLib_BackgroundMode {
            startRanging()
        }
    }
    
    func locationManager(manager: CLLocationManager, didDetermineState state: CLRegionState, forRegion region: CLRegion) {
        if kLineableLib_BackgroundMode {
            startRanging()
        }
    }
    
    func locationManager(manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], inRegion region: CLBeaconRegion) {
        
        for uuid in self.regionsListened.keys {
            if region.proximityUUID.UUIDString == uuid {
                self.regionsListened[uuid] = true
                break
            }
        }
        
        var filteredBeacons = [CLBeacon]()
        for beacon in beacons {
            if beacon.rssi < 0 || beacon.proximity != CLProximity.Unknown {
                filteredBeacons.append(beacon)
            }
        }
        
        for beacon in filteredBeacons {
            
            var hasIt = false
            
            for b in self.listenedBeacons {
                if b == beacon {
                    hasIt = true
                    break
                }
            }
            
            if !hasIt {
                self.listenedBeacons.append(beacon)
            }
        }
        
        if allRegionsListened() {
            LineableController.sharedInstance.updateLineables(withListenedBeacons: self.listenedBeacons)
            
            self.detectToServerIfPossible()
            self.checkForHeartBeat()
        }
        
    }
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        var location:CLLocation? = nil
        
        for l in locations {
            let newLocation = l
            let newLocationAge = -newLocation.timestamp.timeIntervalSinceNow
            
            if newLocationAge > 60.0 || !CLLocationCoordinate2DIsValid(newLocation.coordinate) {
                continue
            }
            
            if newLocation.horizontalAccuracy > 0 {
                location = newLocation
            }
        }
        
        self.lastLocation = location
        
        if let timeStamp = self.lastDetectTimeStamp {
            let interval:Double = NSDate().timeIntervalSinceDate(timeStamp)
            if interval >= kLineableLib_SendLocationTime {
                
                if self.isTracking {
                    startRanging()
                }
                
            }
        }
        
    }
    
    private var lastDetectTimeStamp:NSDate? {
        get {
            if NSUserDefaults.standardUserDefaults().objectForKey("LineableLib_DetectTimeStamp") != nil {
                return NSUserDefaults.standardUserDefaults().objectForKey("LineableLib_DetectTimeStamp") as? NSDate
            }
            else {
                return nil
            }
        }
        set (newValue) {
            NSUserDefaults.standardUserDefaults().setObject(newValue, forKey: "LineableLib_DetectTimeStamp")
            NSUserDefaults.standardUserDefaults().synchronize()
        }
    }
    
    private var lastHeartbeatTimeStamp:NSDate? {
        get {
            if NSUserDefaults.standardUserDefaults().objectForKey("LineableLib_HeartbeatTimeStamp") != nil {
                return NSUserDefaults.standardUserDefaults().objectForKey("LineableLib_HeartbeatTimeStamp") as? NSDate
            }
            else {
                return nil
            }
        }
        set (newValue) {
            NSUserDefaults.standardUserDefaults().setObject(newValue, forKey: "LineableLib_HeartbeatTimeStamp")
            NSUserDefaults.standardUserDefaults().synchronize()
        }
    }
    
    private func detectToServerIfPossible() {
        
        if self.isPreparingDetection {
            return
        }
        
        var timeStamp:NSDate? = nil
        if self.lastDetectTimeStamp != nil {
            timeStamp = self.lastDetectTimeStamp
        }
        
        var needsToDetect = false
        if timeStamp == nil {
            needsToDetect = true
        }
        else {
            
            let interval:Double = NSDate().timeIntervalSinceDate(timeStamp!)
            let locationTimer = kLineableLib_SendLocationTime
            if interval >= locationTimer {
                needsToDetect = true
            }
        }
        
        if needsToDetect {
            self.detectAndSendToServer()
        }
        else {
            self.listenedBeacons.removeAll()
        }

    }
    
    private func checkForHeartBeat() {
        var heartbeatTimeStamp:NSDate? = nil
        if self.lastHeartbeatTimeStamp != nil {
            heartbeatTimeStamp = self.lastHeartbeatTimeStamp
        }
        
        if heartbeatTimeStamp == nil {
            self.sendHeartbeat()
        }
        else {
            
            let interval:Double = NSDate().timeIntervalSinceDate(heartbeatTimeStamp!)
            
            let locationTimer:Double = 3600
            if interval >= locationTimer {
                self.sendHeartbeat()
            }
        }
    }
    
    func detectAndSendToServer() {
        self.isPreparingDetection = true
        self.listenedBeacons.removeAll(keepCapacity: false)
        self.lastDetectTimeStamp = NSDate()
        NSTimer.scheduledTimerWithTimeInterval(kListeningTime, target: self, selector: Selector("sendLineablesToServer"), userInfo: nil, repeats: false)
    }
    
    func sendHeartbeat() {
        self.lastHeartbeatTimeStamp = NSDate()
        self.sendHeartbeat(self.lastLocation)
    }
    
    func sendLineablesToServer() {
        if self.listenedBeacons.count == 0 {
            self.isPreparingDetection = false
            return
        }
        
        if let gateway = self.gateway {
            self.sendDetectedBeaconsAsGateway(gateway, beacons: self.listenedBeacons, location: self.lastLocation, completion: { (result) in
                self.isPreparingDetection = false
                
                if result == 200 {
                    dispatch_async(dispatch_get_main_queue()) {
                        self.delegate?.didDetectLineables(self.listenedBeacons.count, missingLineable:nil)
                        self.listenedBeacons.removeAll()
                    }
                }
                else {
                    self.listenedBeacons.removeAll()
                }
            })
        }
        else {
            var connectedLineables = [Lineable]()
            for lineable in LineableController.sharedInstance.lineables {
                if lineable.device.devicePeripheral?.peripheral?.state == CBPeripheralState.Connected {
                    connectedLineables.append(lineable)
                }
            }
            self.sendDetectedBeacons(self.listenedBeacons, connectedLineables: connectedLineables, location: self.lastLocation, completion: { (result,missingLineable) in
                self.isPreparingDetection = false
                
                if result == 200 {
                    self.missingLineable = missingLineable
                    dispatch_async(dispatch_get_main_queue()) {
                        self.delegate?.didDetectLineables(self.listenedBeacons.count, missingLineable:missingLineable)
                        self.listenedBeacons.removeAll()
                    }
                }
                else {
                    self.listenedBeacons.removeAll()
                }
            })
        }
        
    }
    
    private func allRegionsListened() -> Bool {
        
        var allListened = true
        for uuid in self.regionsListened.keys {
            
            if self.regionsListened[uuid] == false {
                allListened = false
                break
            }
        }
        
        if allListened {
            //Reset Listening Regions
            for uuid in self.regionsListened.keys {
                self.regionsListened[uuid] = false
            }
        }
        
        return allListened
    }
}

struct Gateway {
    let name:String
    let id:String
    
    init(name:String) {
        self.name = name
        self.id = UIDevice.currentDevice().identifierForVendor!.UUIDString + "_iOS"
    }
}

struct LineableRegions {
    
    let uuidstrs:Array<String>
    let regions:Array<CLBeaconRegion>
    var isRangingForRegion = [String:Bool]()
    
    init () {
        
        var regions = [CLBeaconRegion]()
        
        #if DEBUG
            uuidstrs = ["6C4CB629-C88E-4C3E-94D1-F551181F1D18"]
        #else
            uuidstrs = ["C800AD13-745E-4F45-B2A6-E4AE774C4143",
                "91FE354D-A86B-4C5A-A156-B6C20707B204",
                "74278BDA-B644-4520-8F0C-720EAF059935",
                "D64DD386-53D6-4705-B33A-9B54266F6019",
                "9188CC84-45C1-4948-8121-52F93C7C62F0"
            ]
        #endif
        for uuidstr in uuidstrs {
            let uuid = NSUUID(UUIDString: uuidstr)
            let region = CLBeaconRegion(proximityUUID: uuid!, identifier: uuidstr)
            region.notifyEntryStateOnDisplay = true
            region.notifyOnEntry = true
            region.notifyOnExit = true
            
            regions.append(region)
            isRangingForRegion[uuidstr] = false
        }
        
        self.regions = regions
    }
    
}