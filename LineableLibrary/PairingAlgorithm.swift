//
//  PairingAlgorithm.swift
//  LineableExample
//
//  Created by Berrymelon on 2/18/16.
//  Copyright © 2016 Lineable. All rights reserved.
//

import Foundation

struct PairingAlgorithm : Algorithm {
    var description = "Pairing"
    
    var away_buffer = 0
    var away_buffer_max_runner = 3
    let away_buffer_max = 3
    
    var safe_buffer = 0
    var safe_buffer_max = 1
    let safe_signal_limit = -80
    
    var away_signal_average = 0
    let away_signal_limit = -94
    
    var connection_buffer = 0
    let connection_buffer_max = 10
    
    var initialAwayBufferForSafety = 0
    let initialAwayBufferForSafetyMax = 10
    
    private mutating func disconnectChecker(currentStatus:DeviceStatus, signal:Signal) -> Bool {
        
        if currentStatus == .Away {
            if signal.pairedRssi == 0 { return false }
            
            self.connection_buffer++
            if signal.pairedRssi >= self.safe_signal_limit {
                self.connection_buffer = 0
            }
            if self.connection_buffer >= self.connection_buffer_max {
                //Needs to unpair
                self.description = "어웨이인 상태로 페어링이 되어있었는데 \(self.connection_buffer_max)번 동안 \(self.safe_signal_limit)안에 안들어와서 강제로 끊음"
                self.connection_buffer = 0
                return true
            }
        }
        
        if currentStatus == .Safe {
            
            if self.away_signal_average == 0 {
                self.away_signal_average = signal.pairedRssi
            }
            else if signal.pairedRssi != 0 {
                self.away_signal_average = (self.away_signal_average + signal.pairedRssi) / 2
            }
            
            if self.away_signal_average <= away_signal_limit {
                self.description = "신호의 평균이 \(away_signal_limit)보다 낮아서"
                return true
            }
            
        }
        
        return false
    }
    
    mutating func updateStatus(currentStatus:DeviceStatus, device: Device) -> DeviceStatus {
        
        var status = currentStatus
        let signal = device.signal
        
        if self.initialAwayBufferForSafety < self.initialAwayBufferForSafetyMax {
            self.initialAwayBufferForSafety++
        }
        
        if signal.pairedRssi == 0 {
            //Did not listen
            self.safe_buffer = 0
            
            if currentStatus == .Safe {
                self.away_buffer++
                
                if signal.rssi < 0 && signal.rssi >= safe_signal_limit {
                    //Weak Heart but not dead
                    self.away_buffer_max_runner += 2
                }
                
                if self.away_buffer >= self.away_buffer_max_runner && self.initialAwayBufferForSafety >= self.initialAwayBufferForSafetyMax {
                    //AWAY
                    self.away_buffer = 0
                    self.away_buffer_max_runner = self.away_buffer_max
                    self.description = "\(self.away_buffer_max_runner)만큼 페어링 끊어져 있어서 어웨이"
                    status = .Away
                }
            }
            else {
                status = .Away
            }
        }
        else {
            //Did Listen
            self.away_buffer = 0
            self.away_buffer_max_runner = self.away_buffer_max
            
            if currentStatus == .Safe {
                status = .Safe
            }
            else {
                self.safe_buffer++
                if self.safe_buffer >= self.safe_buffer_max && signal.pairedRssi >= self.safe_signal_limit {
                    self.safe_buffer = 0
                    self.description = "\(self.safe_buffer_max)만큼, 신호\(safe_signal_limit)안으로 들어서 세이프"
                    status = .Safe
                }
            }
        }
        
        if self.disconnectChecker(currentStatus, signal: signal) {
            self.away_buffer = 0
            self.away_buffer_max_runner = self.away_buffer_max
            status = .Away
        }
        
        return status
    }
}
