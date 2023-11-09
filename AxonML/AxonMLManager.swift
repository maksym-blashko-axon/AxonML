//
//  AxonMLManager.swift
//  AxonML
//
//  Created by Blashko Maksym on 09.11.2023.
//

import UIKit
import Combine

final public class AxonMLManager: AxonMLProtocol {
    
    // Input
    public var startVideoSession = PassthroughSubject<Void, Never>()
    public var stopVideoSession = PassthroughSubject<Void, Never>()
    public var didTapSwitchCameraButton = PassthroughSubject<Void, Never>()
    public var didTapDetectorsButton = PassthroughSubject<Void, Never>()
    public var didUpdateCameraFrame = PassthroughSubject<CGRect, Never>()
    public var didTapDetect = PassthroughSubject<UIImage, Never>()
    public var clearDetectionAnnotations = PassthroughSubject<Void, Never>()
    
    // Output
    public var onPresentAlert: AnyPublisher<UIAlertController, Never> { _onPresentAlert.eraseToAnyPublisher() }
    public var onSelectDetector: AnyPublisher<DetectorType, Never> { _onSelectDetector.eraseToAnyPublisher() }
    
    // Private
    private let _onPresentAlert = PassthroughSubject<UIAlertController, Never>()
    private let _onSelectDetector = PassthroughSubject<DetectorType, Never>()
    private var cancellables: Set<AnyCancellable> = []
    private var detector: DetectorType = .onDeviceFace
    private var detectorState: DetectorState?
    
    // Servises
    private var dynamicDetector: DynamicDetectionManagerProtocol?
    private var staticDetector: StaticDetectionManagerProtocol?
    
    init() {
        bind()
    }
    
    func bind() {
        startVideoSession
            .sink { [weak self] in
                self?.dynamicDetector?.startSession()
            }.store(in: &cancellables)
        
        stopVideoSession
            .sink { [weak self] in
                self?.dynamicDetector?.stopSession()
            }.store(in: &cancellables)
        
        didTapSwitchCameraButton
            .sink { [weak self] in
                self?.dynamicDetector?.onSwitchCamera()
            }.store(in: &cancellables)
        
        didTapDetectorsButton
            .sink { [weak self] in
                guard let alertController = self?.getDetectorsAlertController() else { return }
                self?._onPresentAlert.send(alertController)
            }.store(in: &cancellables)
        
        didUpdateCameraFrame
            .sink { [weak self] frame in
                self?.dynamicDetector?.onUpdateFrame(frame: frame)
            }.store(in: &cancellables)
        
        didTapDetect
            .sink { [weak self] image in
                self?.staticDetector?.detect(image: image)
            }.store(in: &cancellables)

        clearDetectionAnnotations
            .sink { [weak self] image in
                self?.staticDetector?.clearDetectionAnnotations.send()
            }.store(in: &cancellables)
    }
    
    private func bindToDetectors() {
        staticDetector?.onPresentAlert
            .sink { [weak self] alert in
                self?._onPresentAlert.send(alert)
            }.store(in: &cancellables)
    }
    
    public func configure(_ detectorState: DetectorState) {
        self.detectorState = detectorState
        
        switch detectorState {
        case .dynamicState(let cameraView):
            dynamicDetector = DynamicDetectionManager(cameraView: cameraView)
            
        case .staticState(let imageView):
            staticDetector = StaticDetectionManager(imageView: imageView)
        }
        
        bindToDetectors()
    }
    
    private func getDetectorsAlertController() -> UIAlertController {
        let alertController = UIAlertController(
            title: "Vision Detectors",
            message: "Select a detector",
            preferredStyle: .alert
        )
        
        DetectorType.detectors.forEach { detectorType in
            let action = UIAlertAction(title: detectorType.rawValue, style: .default) { [weak self] (action) in
                guard let value = action.title, let detector = DetectorType(rawValue: value), let detectorState = self?.detectorState else { return }
                
                switch detectorState {
                case .dynamicState:
                    self?.dynamicDetector?.onSelectDetector(detector)
                    
                case .staticState:
                    self?.staticDetector?.onSelectDetector(detector)
                }
                
                self?._onSelectDetector.send(detector)
                self?.detector = detector
            }
            if detectorType.rawValue == detector.rawValue { action.isEnabled = false }
            alertController.addAction(action)
        }
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        return alertController
    }
}
