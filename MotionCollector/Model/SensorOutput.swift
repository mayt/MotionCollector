//
//  SensorOutput.swift
//  DataCollector
//
//  Created by Aleksei Degtiarev on 03/03/2018.
//  Copyright © 2018 Aleksei Degtiarev. All rights reserved.
//

import Foundation


class SensorOutput: Codable {
    
    var timeStamp: Date?
    
    var gyroX: Double?
    var gyroY: Double?
    var gyroZ: Double?
    
    var accX: Double?
    var accY: Double?
    var accZ: Double?
    
    var accGravX: Double?
    var accGravY: Double?
    var accGravZ: Double?
    
    var magX: Double?
    var magY: Double?
    var magZ: Double?
    
    var locX: Double?
    var locY: Double?
    
    var locXAcc: Double?
    var locYAcc: Double?
    
    var altitude: Double?
    
    var speed: Double?
    var speedAcc: Double?
    
    var course: Double?
    var courseAcc: Double?
    
    var locTimeDiff: Double?

    
    
    init() {}
}
