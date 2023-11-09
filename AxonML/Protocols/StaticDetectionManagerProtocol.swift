//
//  StaticDetectionManagerProtocol.swift
//  AxonML
//
//  Created by Blashko Maksym on 09.11.2023.
//

import UIKit
import Combine

protocol StaticDetectionManagerProtocol {
    func detect(image: UIImage)
    func onSelectDetector(_ detector: DetectorType)
    
    var detector: DetectorType { get }
    var onPresentAlert: AnyPublisher<UIAlertController, Never> { get }
    var clearDetectionAnnotations: PassthroughSubject<Void, Never> { get }
}
