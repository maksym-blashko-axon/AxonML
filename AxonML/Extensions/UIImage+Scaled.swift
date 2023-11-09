//
//  UIImage+Scaled.swift
//  AxonML
//
//  Created by Blashko Maksym on 09.11.2023.
//

import UIKit

extension UIImage {
    
    /// Creates and returns a new image scaled to the given size. The image preserves its original PNG
    /// or JPEG bitmap info.
    ///
    /// - Parameter size: The size to scale the image to.
    /// - Returns: The scaled image or `nil` if image could not be resized.
    public func scaledImage(with size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()?.data.flatMap(UIImage.init)
    }
    
    /// The PNG or JPEG data representation of the image or `nil` if the conversion failed.
    private var data: Data? {
        self.pngData() ?? self.jpegData(compressionQuality: 0.8)
    }
}
