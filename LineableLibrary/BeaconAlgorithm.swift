//
//  BeaconAlgorithm.swift
//  LineableExample
//
//  Created by Berrymelon on 2/17/16.
//  Copyright © 2016 Lineable. All rights reserved.
//

import Foundation

struct BeaconAlgorithm : Algorithm {
    var description = "Beacon"
    
    var away_buffer = 0
    let away_buffer_max:Int = 10
    
    var safe_buffer = 0
    let safe_buffer_max = 2
    
    mutating func updateStatus(currentStatus:DeviceStatus, device: Device) -> DeviceStatus {
        
        var status = currentStatus
        
        if device.signal.rssi < 0 {
            self.away_buffer = 0
            
            if currentStatus == .Safe {
                status = .Safe
            }
            else {
                self.safe_buffer++
                if self.safe_buffer >= self.safe_buffer_max {
                    self.safe_buffer = 0
                    self.description = "\(self.safe_buffer_max)만큼 들어서 세이프"
                    status = .Safe
                }
            }
        }
        else {
            self.safe_buffer = 0
            
            if currentStatus == .Safe {
                self.away_buffer++
                if self.away_buffer >= self.away_buffer_max {
                    //AWAY
                    self.away_buffer = 0
                    self.description = "\(self.away_buffer_max)만큼 못 들어서 어웨이"
                    status = .Away
                }
            }
            else {
                status = .Away
            }
        }
        
        return status
    }
}