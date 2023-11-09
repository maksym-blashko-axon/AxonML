//
//  AxonMLProtocol.swift
//  AxonML
//
//  Created by Blashko Maksym on 09.11.2023.
//

import UIKit
import Combine

public protocol AxonMLProtocolInput {
    // MARK: - Dynamic
    /// A subject to trigger the start of a video session.
    var startVideoSession: PassthroughSubject<Void, Never> { get }
    
    /// A subject to trigger the stop of a video session.
    var stopVideoSession: PassthroughSubject<Void, Never> { get }
    
    /// A subject to handle the action when the user taps a button to switch the camera (front/back).
    var didTapSwitchCameraButton: PassthroughSubject<Void, Never> { get }
    
    /// A subject to handle the action when the user taps a button related to detectors.
    var didTapDetectorsButton: PassthroughSubject<Void, Never> { get }
    
    /// A subject to send updated camera frame information.
    var didUpdateCameraFrame: PassthroughSubject<CGRect, Never> { get }
    
    // MARK: - Static
    /// A subject to handle the action when the user taps a button to detect face or object
    var didTapDetect: PassthroughSubject<UIImage, Never> { get }
    
    /// A subject to clear detection annotations.
    var clearDetectionAnnotations: PassthroughSubject<Void, Never> { get }
}

public protocol AxonMLProtocolOutput {
    /// A publisher to receive an alert controller to present.
    var onPresentAlert: AnyPublisher<UIAlertController, Never> { get }
    
    /// A publisher to receive the selected detector type.
    var onSelectDetector: AnyPublisher<DetectorType, Never> { get }
}

public protocol AxonMLProtocol: AxonMLProtocolInput, AxonMLProtocolOutput {
    /// Allows configuring the detector state based on the provided `DetectorState` value.
    func configure(_ detectorState: DetectorState)
}
