//
//  DynamicDetectionManagerProtocol.swift
//  AxonML
//
//  Created by Blashko Maksym on 09.11.2023.
//

import UIKit
import Combine

protocol DynamicDetectionManagerProtocol {
    func startSession()
    func stopSession()
    func onSwitchCamera()
    func onSelectDetector(_ detector: DetectorType)
    func onUpdateFrame(frame: CGRect)
    
    var detector: DetectorType { get }
}
