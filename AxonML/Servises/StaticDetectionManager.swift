//
//  StaticDetectionManager.swift
//  AxonML
//
//  Created by Blashko Maksym on 09.11.2023.
//

import UIKit
import Combine
import MLKit
import SnapKit

final class StaticDetectionManager: NSObject, StaticDetectionManagerProtocol {
    
    private enum Layout {
        static var smallDotRadius: CGFloat { return 5.0 }
        static var largeDotRadius: CGFloat { return 10.0 }
    }
    
    private lazy var imageView: UIImageView = {
        let view = UIImageView()
        view.backgroundColor = .systemGray
        return view
    }()

    /// An overlay view that displays detection annotations.
    private lazy var annotationOverlayView: UIView = {
        let annotationOverlayView = UIView(frame: .zero)
        annotationOverlayView.translatesAutoresizingMaskIntoConstraints = false
        annotationOverlayView.clipsToBounds = true
        return annotationOverlayView
    }()

    public var onPresentAlert: AnyPublisher<UIAlertController, Never> { _onPresentAlert.eraseToAnyPublisher() }
    public var clearDetectionAnnotations = PassthroughSubject<Void, Never>()
    var detector: DetectorType = .onDeviceFace
    
    // Private
    private let _onPresentAlert = PassthroughSubject<UIAlertController, Never>()
    private var cancellables: Set<AnyCancellable> = []
    
    init(imageView: UIImageView) {
        super.init()
        self.imageView = imageView
        setupUI()
        bind()
    }
    
    private func setupUI() {
        imageView.addSubview(annotationOverlayView)
        annotationOverlayView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func bind() {
        clearDetectionAnnotations
            .sink { [weak self] in
                self?.removeDetectionAnnotations()
            }.store(in: &cancellables)
    }
    
    func detect(image: UIImage) {
        removeDetectionAnnotations()
        
        switch detector {
        case .onDeviceFace:
            detectFaces(image: image)
        
        case .onDeviceObject:
            let options = ObjectDetectorOptions()
            options.shouldEnableClassification = false
            options.shouldEnableMultipleObjects = false
            options.detectorMode = .singleImage
            self.detectObjectsOnDevice(in: image, options: options)
        }
    }
    
    func onSelectDetector(_ detector: DetectorType) {
        self.detector = detector
        removeDetectionAnnotations()
    }
}

// MARK: - On-Device detection.
private extension StaticDetectionManager {

    /// Detects faces on the specified image and draws a frame around the detected faces using
    /// On-Device face API.
    ///
    /// - Parameter image: The image.
    func detectFaces(image: UIImage?) {
        guard let image = image else { return }

        // Create a face detector with options.
        // [START config_face]
        let options = FaceDetectorOptions()
        options.landmarkMode = .all
        options.classificationMode = .all
        options.performanceMode = .accurate
        options.contourMode = .all
        // [END config_face]

        // [START init_face]
        let faceDetector = FaceDetector.faceDetector(options: options)
        // [END init_face]

        // Initialize a `VisionImage` object with the given `UIImage`.
        let visionImage = VisionImage(image: image)
        visionImage.orientation = image.imageOrientation

        // [START detect_faces]
        faceDetector.process(visionImage) { [weak self] faces, error in
            guard let self else { return }
            guard error == nil, let faces = faces, !faces.isEmpty else {
                // [START_EXCLUDE]
                let errorString = error?.localizedDescription ?? "No results returned."
                let resultsText = "On-Device face detection failed with error: \(errorString)"
                self.showResults(resultsText)
                // [END_EXCLUDE]
                return
            }

            // Faces detected
            // [START_EXCLUDE]
            faces.forEach { face in
                let transform = self.transformMatrix()
                let transformedRect = face.frame.applying(transform)
                UIUtilities.addRectangle(
                    transformedRect,
                    to: self.annotationOverlayView,
                    color: UIColor.green
                )
                self.addLandmarks(forFace: face, transform: transform)
                self.addContours(forFace: face, transform: transform)
            }
            let resultsText = faces.map { face in
                let headEulerAngleX = face.hasHeadEulerAngleX ? face.headEulerAngleX.description : "NA"
                let headEulerAngleY = face.hasHeadEulerAngleY ? face.headEulerAngleY.description : "NA"
                let headEulerAngleZ = face.hasHeadEulerAngleZ ? face.headEulerAngleZ.description : "NA"
                let leftEyeOpenProbability =
                face.hasLeftEyeOpenProbability
                ? face.leftEyeOpenProbability.description : "NA"
                let rightEyeOpenProbability =
                face.hasRightEyeOpenProbability
                ? face.rightEyeOpenProbability.description : "NA"
                let smilingProbability =
                face.hasSmilingProbability
                ? face.smilingProbability.description : "NA"
                let output = """
            Frame: \(face.frame)
            Head Euler Angle X: \(headEulerAngleX)
            Head Euler Angle Y: \(headEulerAngleY)
            Head Euler Angle Z: \(headEulerAngleZ)
            Left Eye Open Probability: \(leftEyeOpenProbability)
            Right Eye Open Probability: \(rightEyeOpenProbability)
            Smiling Probability: \(smilingProbability)
            """
                return "\(output)"
            }.joined(separator: "\n")
            self.showResults(resultsText)
            // [END_EXCLUDE]
        }
        // [END detect_faces]
    }

    /// Detects objects on the specified image and draws a frame around them.
    ///
    /// - Parameter image: The image.
    /// - Parameter options: The options for object detector.
    func detectObjectsOnDevice(in image: UIImage?, options: CommonObjectDetectorOptions) {
        guard let image = image else { return }

        // Initialize a `VisionImage` object with the given `UIImage`.
        let visionImage = VisionImage(image: image)
        visionImage.orientation = image.imageOrientation

        // [START init_object_detector]
        // Create an objects detector with options.
        let detector = ObjectDetector.objectDetector(options: options)
        // [END init_object_detector]

        // [START detect_object]
        detector.process(visionImage) { [weak self] objects, error in
            guard let self else { return }
            guard error == nil else {
                // [START_EXCLUDE]
                let errorString = error?.localizedDescription ?? "No results returned."
                let resultsText = "Object detection failed with error: \(errorString)"
                self.showResults(resultsText)
                // [END_EXCLUDE]
                return
            }
            guard let objects = objects, !objects.isEmpty else {
                // [START_EXCLUDE]
                let resultsText = "On-Device object detector returned no results."
                self.showResults(resultsText)
                // [END_EXCLUDE]
                return
            }

            objects.forEach { object in
                // [START_EXCLUDE]
                let transform = self.transformMatrix()
                let transformedRect = object.frame.applying(transform)
                UIUtilities.addRectangle(
                    transformedRect,
                    to: self.annotationOverlayView,
                    color: .green
                )
                // [END_EXCLUDE]
            }

            // [START_EXCLUDE]
            let resultsText = objects.map { object in
                var description = "Frame: \(object.frame)\n"
                if let trackingID = object.trackingID {
                    description += "Object ID: " + trackingID.stringValue + "\n"
                }
                description += object.labels.enumerated().map { (index, label) in
                    "Label \(index): \(label.text), \(label.confidence), \(label.index)"
                }.joined(separator: "\n")
                return description
            }.joined(separator: "\n")

            self.showResults(resultsText)
            // [END_EXCLUDE]
        }
        // [END detect_object]
    }
}

// MARK: Private
private extension StaticDetectionManager {

    func showResults(_ message: String) {
        let resultsAlertController = UIAlertController(
            title: "Detection Results",
            message: nil,
            preferredStyle: .actionSheet
        )
        resultsAlertController.addAction(
            UIAlertAction(title: "Ok", style: .destructive) { _ in
                resultsAlertController.dismiss(animated: true, completion: nil)
            }
        )
        resultsAlertController.message = message
        _onPresentAlert.send(resultsAlertController)
    }

    /// Removes the detection annotations from the annotation overlay view.
    func removeDetectionAnnotations() {
        for annotationView in annotationOverlayView.subviews {
            annotationView.removeFromSuperview()
        }
    }

    /// Updates the image view with a scaled version of the given image.
    func updateImageView(with image: UIImage) {
        let orientation = UIApplication.shared.statusBarOrientation
        var scaledImageWidth: CGFloat = 0.0
        var scaledImageHeight: CGFloat = 0.0

        switch orientation {
        case .portrait, .portraitUpsideDown, .unknown:
            scaledImageWidth = imageView.bounds.size.width
            scaledImageHeight = image.size.height * scaledImageWidth / image.size.width

        case .landscapeLeft, .landscapeRight:
            scaledImageWidth = image.size.width * scaledImageHeight / image.size.height
            scaledImageHeight = imageView.bounds.size.height

        @unknown default:
            fatalError()
        }

        DispatchQueue.global(qos: .userInitiated).async {
            // Scale image while maintaining aspect ratio so it displays better in the UIImageView.
            var scaledImage = image.scaledImage(
                with: CGSize(width: scaledImageWidth, height: scaledImageHeight)
            )
            scaledImage = scaledImage ?? image
            guard let finalImage = scaledImage else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.imageView.image = finalImage
            }
        }
    }

    func transformMatrix() -> CGAffineTransform {
        guard let image = imageView.image else { return CGAffineTransform() }
        let imageViewWidth = imageView.frame.size.width
        let imageViewHeight = imageView.frame.size.height
        let imageWidth = image.size.width
        let imageHeight = image.size.height

        let imageViewAspectRatio = imageViewWidth / imageViewHeight
        let imageAspectRatio = imageWidth / imageHeight
        let scale =
        (imageViewAspectRatio > imageAspectRatio)
        ? imageViewHeight / imageHeight : imageViewWidth / imageWidth

        // Image view's `contentMode` is `scaleAspectFit`, which scales the image to fit the size of the
        // image view by maintaining the aspect ratio. Multiple by `scale` to get image's original size.
        let scaledImageWidth = imageWidth * scale
        let scaledImageHeight = imageHeight * scale
        let xValue = (imageViewWidth - scaledImageWidth) / CGFloat(2.0)
        let yValue = (imageViewHeight - scaledImageHeight) / CGFloat(2.0)

        var transform = CGAffineTransform.identity.translatedBy(x: xValue, y: yValue)
        transform = transform.scaledBy(x: scale, y: scale)
        return transform
    }

    func pointFrom(_ visionPoint: VisionPoint) -> CGPoint {
        return CGPoint(x: visionPoint.x, y: visionPoint.y)
    }

    func addContours(forFace face: Face, transform: CGAffineTransform) {
        // Face
        if let faceContour = face.contour(ofType: .face) {
            for point in faceContour.points {
                let transformedPoint = pointFrom(point).applying(transform)
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Layout.smallDotRadius
                )
            }
        }

        // Eyebrows
        if let topLeftEyebrowContour = face.contour(ofType: .leftEyebrowTop) {
            for point in topLeftEyebrowContour.points {
                let transformedPoint = pointFrom(point).applying(transform)
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Layout.smallDotRadius
                )
            }
        }
        if let bottomLeftEyebrowContour = face.contour(ofType: .leftEyebrowBottom) {
            for point in bottomLeftEyebrowContour.points {
                let transformedPoint = pointFrom(point).applying(transform)
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Layout.smallDotRadius
                )
            }
        }
        if let topRightEyebrowContour = face.contour(ofType: .rightEyebrowTop) {
            for point in topRightEyebrowContour.points {
                let transformedPoint = pointFrom(point).applying(transform)
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Layout.smallDotRadius
                )
            }
        }
        if let bottomRightEyebrowContour = face.contour(ofType: .rightEyebrowBottom) {
            for point in bottomRightEyebrowContour.points {
                let transformedPoint = pointFrom(point).applying(transform)
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Layout.smallDotRadius
                )
            }
        }

        // Eyes
        if let leftEyeContour = face.contour(ofType: .leftEye) {
            for point in leftEyeContour.points {
                let transformedPoint = pointFrom(point).applying(transform)
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Layout.smallDotRadius)
            }
        }
        if let rightEyeContour = face.contour(ofType: .rightEye) {
            for point in rightEyeContour.points {
                let transformedPoint = pointFrom(point).applying(transform)
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Layout.smallDotRadius
                )
            }
        }

        // Lips
        if let topUpperLipContour = face.contour(ofType: .upperLipTop) {
            for point in topUpperLipContour.points {
                let transformedPoint = pointFrom(point).applying(transform)
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Layout.smallDotRadius
                )
            }
        }
        if let bottomUpperLipContour = face.contour(ofType: .upperLipBottom) {
            for point in bottomUpperLipContour.points {
                let transformedPoint = pointFrom(point).applying(transform)
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Layout.smallDotRadius
                )
            }
        }
        if let topLowerLipContour = face.contour(ofType: .lowerLipTop) {
            for point in topLowerLipContour.points {
                let transformedPoint = pointFrom(point).applying(transform)
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Layout.smallDotRadius
                )
            }
        }
        if let bottomLowerLipContour = face.contour(ofType: .lowerLipBottom) {
            for point in bottomLowerLipContour.points {
                let transformedPoint = pointFrom(point).applying(transform)
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Layout.smallDotRadius
                )
            }
        }

        // Nose
        if let noseBridgeContour = face.contour(ofType: .noseBridge) {
            for point in noseBridgeContour.points {
                let transformedPoint = pointFrom(point).applying(transform)
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Layout.smallDotRadius
                )
            }
        }
        if let noseBottomContour = face.contour(ofType: .noseBottom) {
            for point in noseBottomContour.points {
                let transformedPoint = pointFrom(point).applying(transform)
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Layout.smallDotRadius
                )
            }
        }
    }

    func addLandmarks(forFace face: Face, transform: CGAffineTransform) {
        // Mouth
        if let bottomMouthLandmark = face.landmark(ofType: .mouthBottom) {
            let point = pointFrom(bottomMouthLandmark.position)
            let transformedPoint = point.applying(transform)
            UIUtilities.addCircle(
                atPoint: transformedPoint,
                to: annotationOverlayView,
                color: UIColor.red,
                radius: Layout.largeDotRadius
            )
        }
        if let leftMouthLandmark = face.landmark(ofType: .mouthLeft) {
            let point = pointFrom(leftMouthLandmark.position)
            let transformedPoint = point.applying(transform)
            UIUtilities.addCircle(
                atPoint: transformedPoint,
                to: annotationOverlayView,
                color: UIColor.red,
                radius: Layout.largeDotRadius
            )
        }
        if let rightMouthLandmark = face.landmark(ofType: .mouthRight) {
            let point = pointFrom(rightMouthLandmark.position)
            let transformedPoint = point.applying(transform)
            UIUtilities.addCircle(
                atPoint: transformedPoint,
                to: annotationOverlayView,
                color: UIColor.red,
                radius: Layout.largeDotRadius
            )
        }

        // Nose
        if let noseBaseLandmark = face.landmark(ofType: .noseBase) {
            let point = pointFrom(noseBaseLandmark.position)
            let transformedPoint = point.applying(transform)
            UIUtilities.addCircle(
                atPoint: transformedPoint,
                to: annotationOverlayView,
                color: UIColor.yellow,
                radius: Layout.largeDotRadius
            )
        }

        // Eyes
        if let leftEyeLandmark = face.landmark(ofType: .leftEye) {
            let point = pointFrom(leftEyeLandmark.position)
            let transformedPoint = point.applying(transform)
            UIUtilities.addCircle(
                atPoint: transformedPoint,
                to: annotationOverlayView,
                color: UIColor.cyan,
                radius: Layout.largeDotRadius
            )
        }
        if let rightEyeLandmark = face.landmark(ofType: .rightEye) {
            let point = pointFrom(rightEyeLandmark.position)
            let transformedPoint = point.applying(transform)
            UIUtilities.addCircle(
                atPoint: transformedPoint,
                to: annotationOverlayView,
                color: UIColor.cyan,
                radius: Layout.largeDotRadius
            )
        }

        // Ears
        if let leftEarLandmark = face.landmark(ofType: .leftEar) {
            let point = pointFrom(leftEarLandmark.position)
            let transformedPoint = point.applying(transform)
            UIUtilities.addCircle(
                atPoint: transformedPoint,
                to: annotationOverlayView,
                color: UIColor.purple,
                radius: Layout.largeDotRadius
            )
        }
        if let rightEarLandmark = face.landmark(ofType: .rightEar) {
            let point = pointFrom(rightEarLandmark.position)
            let transformedPoint = point.applying(transform)
            UIUtilities.addCircle(
                atPoint: transformedPoint,
                to: annotationOverlayView,
                color: UIColor.purple,
                radius: Layout.largeDotRadius
            )
        }

        // Cheeks
        if let leftCheekLandmark = face.landmark(ofType: .leftCheek) {
            let point = pointFrom(leftCheekLandmark.position)
            let transformedPoint = point.applying(transform)
            UIUtilities.addCircle(
                atPoint: transformedPoint,
                to: annotationOverlayView,
                color: UIColor.orange,
                radius: Layout.largeDotRadius
            )
        }
        if let rightCheekLandmark = face.landmark(ofType: .rightCheek) {
            let point = pointFrom(rightCheekLandmark.position)
            let transformedPoint = point.applying(transform)
            UIUtilities.addCircle(
                atPoint: transformedPoint,
                to: annotationOverlayView,
                color: UIColor.orange,
                radius: Layout.largeDotRadius
            )
        }
    }
}
