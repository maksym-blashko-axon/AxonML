//
//  DetectorState.swift
//  AxonML
//
//  Created by Blashko Maksym on 09.11.2023.
//

import UIKit

public enum DetectorState: Equatable {
    case dynamicState(cameraView: UIView)
    case staticState(imageView: UIImageView)
}
