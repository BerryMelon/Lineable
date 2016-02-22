//
//  LineableControllerManagers.swift
//  LineableExample
//
//  Created by Berrymelon on 2/18/16.
//  Copyright © 2016 Lineable. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth

extension LineableController {
    
    func updateLineable(lineable:Lineable) {
        
        var didUpdate = false
        var index = 0
        for myLineable in self.lineables {
            if myLineable == lineable {

                self.lineables[index] = lineable
                didUpdate = true
                break
            }
            
            index++
        }
        
        if !didUpdate { return }
        
        self.save()
    }
    
    func updateProtectorStateForLineable(lineable:Lineable,protectorSeq:Int,state:ProtectorState) {
        lineable.updateProtectorState(protectorSeq, state: state)
    }
    
    func addLineable(lineable:Lineable) {
        
        for myLineable in self.lineables {
            if myLineable == lineable {
                self.updateLineable(lineable)
                return
            }
        }
        
        self.lineables.append(lineable)
        self.save()
    }
    
    func removeLineable(lineable:Lineable) -> Int? {
        
        var hasit = false
        var index = 0
        for myLineable in self.lineables {
            if myLineable == lineable {
                hasit = true
                break
            }
            
            index++
        }
        
        if !hasit { return nil }
        
        self.lineables.removeAtIndex(index)
        
        self.save()
        
        return index
    }
    
    func isMyLineable(lineable:Lineable) -> Bool {
        
        var isMine = false
        
        for myLineable in self.lineables {
            if myLineable == lineable {
                isMine = true
                break
            }
        }
        
        return isMine
    }
    
    func lineableWithSeq(seq:Int) -> Lineable? {
        
        for myLineable in self.lineables {
            if myLineable.seq == seq {
                return myLineable
            }
        }
        
        return nil
    }
    
    func indexOfLineable(lineable:Lineable) -> Int? {
        var index = 0
        for myLineable in self.lineables {
            if myLineable == lineable {
                return index
            }
            index++
        }
        
        return nil
    }
    
    func updateMyself() {
        guard let user = User.me else { return }
        
        for lineable in self.lineables {
            
            for index in 0..<lineable.protectors.count {
                
                if lineable.protectors[index].isMe() {
                    //This is me. update.
                    lineable.protectors[index].photoUrl = user.photoUrl
                    lineable.protectors[index].name = user.name!
                    lineable.protectors[index].appPushId = user.appPushID!
                    return
                }
            }
            
        }
    }
    
    func removeProtector(protectorSeq:Int, fromLineable lineableSeq:Int) {
        
        lineableLoop: for lineable in self.lineables {
            
            if lineable.seq == lineableSeq {
                var index = 0
                protectorLoop: for protector in lineable.protectors {
                    if protector.seq == protectorSeq {
                        lineable.protectors.removeAtIndex(index)
                        break lineableLoop
                    }
                    index++
                }
            }
        }
    }
    
    func getAvailableUUID() -> String {
        #if DEBUG
            let uuid = "6C4CB629-C88E-4C3E-94D1-F551181F1D18"
        #else
            let myLineablesCount = self.lineables.count
            
            let uuids = LineableDetector.sharedDetector.lineableRegions.uuidstrs
            let uuidCount = uuids.count
            
            let index = myLineablesCount % uuidCount
            
            let uuid = uuids[index]
        #endif
        
        return uuid
    }
    
}