//
//  Algorithm.swift
//  LineableExample
//
//  Created by Berrymelon on 2/17/16.
//  Copyright © 2016 Lineable. All rights reserved.
//

import Foundation
import CoreLocation
import CoreBluetooth

protocol Algorithm : CustomStringConvertible {
    mutating func updateStatus(currentStatus:DeviceStatus, device:Device) -> DeviceStatus
}

extension Algorithm {
    
}
