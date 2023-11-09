//
//  DetectorType.swift
//  AxonML
//
//  Created by Blashko Maksym on 09.11.2023.
//

import Foundation

public enum DetectorType: String {
    case onDeviceFace = "Face Detection"
    case onDeviceObject = "Object Detection"
    
    static let detectors: [DetectorType] = [
        .onDeviceFace,
        .onDeviceObject
    ]
}
