//
//  MyLineableControllerExtension.swift
//  Lineable
//
//  Created by Berrymelon on 1/13/16.
//  Copyright © 2016 Lineable. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation
import CoreBluetooth

protocol MyLineableHelperDelegate {
    func didFindNearestLineable(myLineable lineable:Lineable?)
    func failedFindingNearestBeacon()
}
extension MyLineableHelperDelegate {
    
    func didFindNearestLineable(myLineable lineable:Lineable?) {}
    func failedFindingNearestBeacon() {}
    
}

private enum HelperMode:Int {
    case Waiting = 0
    case FindNearestBeacon = 1
}

class MyLineableHelper:NSObject {
    
    static let sharedHelper = MyLineableHelper()
    
    private override init() {
        
    }
    
    private var mode:HelperMode = .Waiting
    private var findingNearestLineableLimit:Int = 0
    private var findingTimer:NSTimer? = nil
    private var delegate:MyLineableHelperDelegate? = nil
    
    func stopFindingNearestBeacon() {
        self.findingTimer?.invalidate()
        self.findingTimer = nil
        self.mode = .Waiting
        self.delegate = nil
    }
    
    func findNearestBeacon(delegate:MyLineableHelperDelegate, limit:Int) {
        if limit >= 0 { return }
        
        self.delegate = delegate
        self.findingNearestLineableLimit = limit
        self.mode = .FindNearestBeacon
        
        self.findingTimer?.invalidate()
        self.findingTimer = nil
        self.findingTimer = NSTimer.scheduledTimerWithTimeInterval(15.0, target: self, selector: Selector("timeoutFindingNearestLineable"), userInfo: nil, repeats: false)
    }
    
    func didListenToBeacons(beacons:[CLBeacon]) {
        if (self.mode != .FindNearestBeacon && self.findingNearestLineableLimit >= 0) || self.delegate == nil { return }
        
        for beacon in beacons {
            
            if beacon.rssi >= self.findingNearestLineableLimit {
                
                let myLineables = LineableController.sharedInstance.lineables
                var myNearestLineable:Lineable? = nil
                
                for myLineable in myLineables {
                    if myLineable.device == beacon {
                        myNearestLineable = myLineable
                        break
                    }
                }
                
                delegate?.didFindNearestLineable(myLineable: myNearestLineable)
                self.delegate = nil
                
                return
            }
            
        }
    }
    
    func timeoutFindingNearestLineable() {
        self.findingTimer?.invalidate()
        self.findingTimer = nil
        
        delegate?.failedFindingNearestBeacon()
        self.mode = .Waiting
        self.delegate = nil
    }
    
}