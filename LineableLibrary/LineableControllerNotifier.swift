//
//  LineableControllerNotifier.swift
//  LineableExample
//
//  Created by Berrymelon on 2/17/16.
//  Copyright © 2016 Lineable. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth

extension LineableController {
    
    func addDelegate(delegate:LineableControllerDelegate) {
        self.delegates.append(delegate)
    }
    
    func removeDelegate(delegate:LineableControllerDelegate) {
        for (var i=0; i<self.delegates.count; ++i) {
            if self.delegates[i].isEqual(delegate) {
                self.delegates.removeAtIndex(i)
                break;
            }
        }
    }
    
    func notifyAway(lineable:Lineable) {
        for delegate in delegates {
            
            if delegate.lineableSeq != nil {
                if lineable.seq == delegate.lineableSeq! {
                    delegate.lineableBecameAway(lineable)
                }
            }
            else {
                delegate.lineableBecameAway(lineable)
            }
        }
    }
    
    func notifySafe(lineable:Lineable) {
        for delegate in delegates {
            if delegate.lineableSeq != nil {
                if lineable.seq == delegate.lineableSeq! {
                    delegate.lineableBecameSafe(lineable)
                }
            }
            else {
                delegate.lineableBecameSafe(lineable)
            }
        }
    }
    
    func notifyListenedToMyLineables(lineables:[Lineable]) {
        for delegate in delegates {
            delegate.listenedToMyLineables(lineables)
        }
    }
    
    func notifyListenedToLineable(lineable:Lineable) {
        for delegate in delegates {
            if delegate.lineableSeq == lineable.seq {
                delegate.listenedToMyLineable(lineable)
                break
            }
        }
    }
    
    func notifyLowBattery(lineable:Lineable,batteryLevel:Double) {
        for delegate in delegates {
            delegate.lineableHasLowBattery(lineable, batteryLevel: batteryLevel)
        }
    }
    
    func notifyCentralManagerDidUpdateState(state:CBCentralManagerState) {
        for delegate in delegates {
            delegate.bluetoothStatusChanged(state)
        }
    }
    
    func notifyScanningLineable(lineable:Lineable) {
        for delegate in delegates {
            delegate.willStartScanningLineable(lineable)
        }
    }
    
    func notifyConnectingLineable(lineable:Lineable) {
        for delegate in delegates {
            delegate.willStartConnectingLineable(lineable)
        }
    }
    
    func notifyDisconnectingLineable(lineable:Lineable) {
        for delegate in delegates {
            delegate.willStartDisconnectingLineable(lineable)
        }
    }
    
    func notifyDidConnectLineable(lineable:Lineable) {
        for delegate in delegates {
            delegate.didConnectLineable(lineable)
        }
    }
    
    func notifyDidDisconnectLineable(lineable:Lineable) {
        for delegate in delegates {
            delegate.didDisconnectLineable(lineable)
        }
    }
    
    func notifyDidFailToConnectLineable(lineable:Lineable, error:NSError?) {
        for delegate in delegates {
            delegate.didFailToConnectLineable(lineable, error: error)
        }
    }
    
    func notifyDiscoveredCharacteristicsForLineable(lineable:Lineable, characteristics:[CBCharacteristic]) {
        for delegate in delegates {
            delegate.discoveredCharacteristicsForLineable(lineable, characteristics: characteristics)
        }
    }
    
}
