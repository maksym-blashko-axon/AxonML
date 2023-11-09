//
//  DynamicDetectionManager.swift
//  AxonML
//
//  Created by Blashko Maksym on 09.11.2023.
//

import AVFoundation
import Combine
import UIKit
import CoreVideo
import MLImage
import MLKit
import SnapKit

final class DynamicDetectionManager: NSObject, DynamicDetectionManagerProtocol {
    
    private enum Layout {
        static var smallDotRadius: CGFloat { return 4.0 }
    }
    
    private var isUsingFrontCamera = true
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var captureSession = AVCaptureSession()
    private var sessionQueue = DispatchQueue(label: "com.google.mlkit.visiondetector.SessionQueue")
    private var lastFrame: CMSampleBuffer?
    private var cameraView: UIView?
    
    private lazy var previewOverlayView: UIImageView = {
        let previewOverlayView = UIImageView(frame: .zero)
        previewOverlayView.contentMode = UIView.ContentMode.scaleAspectFill
        previewOverlayView.translatesAutoresizingMaskIntoConstraints = false
        return previewOverlayView
    }()
    
    private lazy var annotationOverlayView: UIView = {
        let annotationOverlayView = UIView(frame: .zero)
        annotationOverlayView.translatesAutoresizingMaskIntoConstraints = false
        return annotationOverlayView
    }()
    
    /// The detector mode with which detection was most recently run. Only used on the video output
    /// queue. Useful for inferring when to reset detector instances which use a conventional
    /// lifecyle paradigm.
    private var lastDetector: DetectorType?
    
    var detector: DetectorType = .onDeviceFace
    
    init(cameraView: UIView) {
        self.cameraView = cameraView
        super.init()
        setupUI()
        setUpCaptureSessionOutput()
        setUpCaptureSessionInput()
        bindInputs()
        bindOutputs()
    }
    
    func bindInputs() {
        
    }
    
    func bindOutputs() {
        
    }
    
    private func setupUI() {
        guard let cameraView else { return }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
        cameraView.addSubview(previewOverlayView)
        previewOverlayView.snp.makeConstraints { make in
            make.centerX.centerY.equalToSuperview()
            make.leading.trailing.equalToSuperview()
        }
        
        cameraView.addSubview(annotationOverlayView)
        annotationOverlayView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.captureSession.startRunning()
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.captureSession.stopRunning()
        }
    }
    
    func onSwitchCamera() {
        isUsingFrontCamera = !isUsingFrontCamera
        removeDetectionAnnotations()
        setUpCaptureSessionInput()
    }
    
    func onSelectDetector(_ detector: DetectorType) {
        self.detector = detector
        removeDetectionAnnotations()
    }
    
    func onUpdateFrame(frame: CGRect) {
        previewLayer.frame = frame
    }
}

// MARK: AVCaptureVideoDataOutputSampleBufferDelegate
extension DynamicDetectionManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to get image buffer from sample buffer.")
            return
        }
        // Evaluate `self.currentDetector` once to ensure consistency throughout this method since it
        // can be concurrently modified from the main thread.
        let activeDetector = self.detector
        resetManagedLifecycleDetectors(activeDetector: activeDetector)
        
        lastFrame = sampleBuffer
        let visionImage = VisionImage(buffer: sampleBuffer)
        let orientation = UIUtilities.imageOrientation(
            fromDevicePosition: isUsingFrontCamera ? .front : .back
        )
        visionImage.orientation = orientation
        
        guard let inputImage = MLImage(sampleBuffer: sampleBuffer) else {
            print("Failed to create MLImage from sample buffer.")
            return
        }
        inputImage.orientation = orientation
        
        let imageWidth = CGFloat(CVPixelBufferGetWidth(imageBuffer))
        let imageHeight = CGFloat(CVPixelBufferGetHeight(imageBuffer))
        
        switch activeDetector {
        case .onDeviceFace:
            detectFacesOnDevice(in: visionImage, width: imageWidth, height: imageHeight)
            
        case .onDeviceObject:
            // The `options.detectorMode` defaults to `.stream`
            let options = ObjectDetectorOptions()
            options.shouldEnableClassification = false
            options.shouldEnableMultipleObjects = false
            detectObjectsOnDevice(
                in: visionImage,
                width: imageWidth,
                height: imageHeight,
                options: options)
        }
    }
}

// MARK: On-Device Detections
private extension DynamicDetectionManager {
    func detectFacesOnDevice(in image: VisionImage, width: CGFloat, height: CGFloat) {
        // When performing latency tests to determine ideal detection settings, run the app in 'release'
        // mode to get accurate performance metrics.
        let options = FaceDetectorOptions()
        options.landmarkMode = .none
        options.contourMode = .all
        options.classificationMode = .none
        options.performanceMode = .fast
        let faceDetector = FaceDetector.faceDetector(options: options)
        var faces: [Face] = []
        var detectionError: Error?
        do {
            faces = try faceDetector.results(in: image)
        } catch let error {
            detectionError = error
        }
        
        DispatchQueue.main.sync {
            updatePreviewOverlayViewWithLastFrame()
            if let detectionError = detectionError {
                print("Failed to detect faces with error: \(detectionError.localizedDescription).")
                return
            }
            guard !faces.isEmpty else {
                print("On-Device face detector returned no results.")
                return
            }
            
            for face in faces {
                let normalizedRect = CGRect(
                    x: face.frame.origin.x / width,
                    y: face.frame.origin.y / height,
                    width: face.frame.size.width / width,
                    height: face.frame.size.height / height
                )
                let standardizedRect = previewLayer.layerRectConverted(fromMetadataOutputRect: normalizedRect).standardized
                UIUtilities.addRectangle(
                    standardizedRect,
                    to: annotationOverlayView,
                    color: UIColor.green
                )
                addContours(for: face, width: width, height: height)
            }
        }
    }
    
    func detectObjectsOnDevice(in image: VisionImage, width: CGFloat, height: CGFloat, options: CommonObjectDetectorOptions) {
        let detector = ObjectDetector.objectDetector(options: options)
        var objects: [Object] = []
        var detectionError: Error? = nil
        do {
            objects = try detector.results(in: image)
        } catch let error {
            detectionError = error
        }
        
        DispatchQueue.main.sync {
            updatePreviewOverlayViewWithLastFrame()
            if let detectionError = detectionError {
                print("Failed to detect objects with error: \(detectionError.localizedDescription).")
                return
                
            }
            guard !objects.isEmpty else {
                print("On-Device object detector returned no results.")
                return
            }
            
            for object in objects {
                let normalizedRect = CGRect(
                    x: object.frame.origin.x / width,
                    y: object.frame.origin.y / height,
                    width: object.frame.size.width / width,
                    height: object.frame.size.height / height
                )
                let standardizedRect = previewLayer.layerRectConverted(fromMetadataOutputRect: normalizedRect).standardized
                UIUtilities.addRectangle(
                    standardizedRect,
                    to: annotationOverlayView,
                    color: UIColor.green
                )
                let label = UILabel(frame: standardizedRect)
                var description = ""
                if let trackingID = object.trackingID {
                    description += "Object ID: " + trackingID.stringValue + "\n"
                }
                description += object.labels.enumerated().map { (index, label) in
                    "Label \(index): \(label.text), \(label.confidence), \(label.index)"
                }.joined(separator: "\n")
                
                label.text = description
                label.numberOfLines = 0
                label.adjustsFontSizeToFitWidth = true
                rotate(label, orientation: image.orientation)
                annotationOverlayView.addSubview(label)
            }
        }
    }
}

// MARK: Private
private extension DynamicDetectionManager {
    func setUpCaptureSessionOutput() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.captureSession.beginConfiguration()
            // When performing latency tests to determine ideal capture settings,
            // run the app in 'release' mode to get accurate performance metrics
            self.captureSession.sessionPreset = AVCaptureSession.Preset.medium
            
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [
                (kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA
            ]
            output.alwaysDiscardsLateVideoFrames = true
            let outputQueue = DispatchQueue(label: "com.google.mlkit.visiondetector.VideoDataOutputQueue")
            output.setSampleBufferDelegate(self, queue: outputQueue)
            guard self.captureSession.canAddOutput(output) else {
                print("Failed to add capture session output.")
                return
            }
            self.captureSession.addOutput(output)
            self.captureSession.commitConfiguration()
        }
    }
    
    func setUpCaptureSessionInput() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let cameraPosition: AVCaptureDevice.Position = self.isUsingFrontCamera ? .front : .back
            guard let device = captureDevice(forPosition: cameraPosition) else {
                print("Failed to get capture device for camera position: \(cameraPosition)")
                return
            }
            do {
                self.captureSession.beginConfiguration()
                let currentInputs = self.captureSession.inputs
                for input in currentInputs {
                    self.captureSession.removeInput(input)
                }
                
                let input = try AVCaptureDeviceInput(device: device)
                guard self.captureSession.canAddInput(input) else {
                    print("Failed to add capture session input.")
                    return
                }
                self.captureSession.addInput(input)
                self.captureSession.commitConfiguration()
            } catch {
                print("Failed to create capture device input: \(error.localizedDescription)")
            }
        }
    }
    
    func captureDevice(forPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if #available(iOS 10.0, *) {
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera],
                mediaType: .video,
                position: .unspecified
            )
            return discoverySession.devices.first { $0.position == position }
        }
        return nil
    }
    
    func removeDetectionAnnotations() {
        for annotationView in annotationOverlayView.subviews {
            annotationView.removeFromSuperview()
        }
    }
    
    func updatePreviewOverlayViewWithLastFrame() {
        guard let lastFrame = lastFrame,
              let imageBuffer = CMSampleBufferGetImageBuffer(lastFrame)
        else {
            return
        }
        self.updatePreviewOverlayViewWithImageBuffer(imageBuffer)
        self.removeDetectionAnnotations()
    }
    
    func updatePreviewOverlayViewWithImageBuffer(_ imageBuffer: CVImageBuffer?) {
        guard let imageBuffer = imageBuffer else { return }
        
        let orientation: UIImage.Orientation = isUsingFrontCamera ? .leftMirrored : .right
        let image = UIUtilities.createUIImage(from: imageBuffer, orientation: orientation)
        previewOverlayView.image = image
    }
    
    func normalizedPoint(fromVisionPoint point: VisionPoint, width: CGFloat, height: CGFloat) -> CGPoint {
        let cgPoint = CGPoint(x: point.x, y: point.y)
        var normalizedPoint = CGPoint(x: cgPoint.x / width, y: cgPoint.y / height)
        normalizedPoint = previewLayer.layerPointConverted(fromCaptureDevicePoint: normalizedPoint)
        return normalizedPoint
    }
    
    func addContours(for face: Face, width: CGFloat, height: CGFloat) {
        // Face
        if let faceContour = face.contour(ofType: .face) {
            for point in faceContour.points {
                let cgPoint = normalizedPoint(fromVisionPoint: point, width: width, height: height)
                UIUtilities.addCircle(
                    atPoint: cgPoint,
                    to: annotationOverlayView,
                    color: UIColor.blue,
                    radius: Layout.smallDotRadius
                )
            }
        }
        
        // Eyebrows
        if let topLeftEyebrowContour = face.contour(ofType: .leftEyebrowTop) {
            for point in topLeftEyebrowContour.points {
                let cgPoint = normalizedPoint(fromVisionPoint: point, width: width, height: height)
                UIUtilities.addCircle(
                    atPoint: cgPoint,
                    to: annotationOverlayView,
                    color: UIColor.orange,
                    radius: Layout.smallDotRadius
                )
            }
        }
        if let bottomLeftEyebrowContour = face.contour(ofType: .leftEyebrowBottom) {
            for point in bottomLeftEyebrowContour.points {
                let cgPoint = normalizedPoint(fromVisionPoint: point, width: width, height: height)
                UIUtilities.addCircle(
                    atPoint: cgPoint,
                    to: annotationOverlayView,
                    color: UIColor.orange,
                    radius: Layout.smallDotRadius
                )
            }
        }
        if let topRightEyebrowContour = face.contour(ofType: .rightEyebrowTop) {
            for point in topRightEyebrowContour.points {
                let cgPoint = normalizedPoint(fromVisionPoint: point, width: width, height: height)
                UIUtilities.addCircle(
                    atPoint: cgPoint,
                    to: annotationOverlayView,
                    color: UIColor.orange,
                    radius: Layout.smallDotRadius
                )
            }
        }
        if let bottomRightEyebrowContour = face.contour(ofType: .rightEyebrowBottom) {
            for point in bottomRightEyebrowContour.points {
                let cgPoint = normalizedPoint(fromVisionPoint: point, width: width, height: height)
                UIUtilities.addCircle(
                    atPoint: cgPoint,
                    to: annotationOverlayView,
                    color: UIColor.orange,
                    radius: Layout.smallDotRadius
                )
            }
        }
        
        // Eyes
        if let leftEyeContour = face.contour(ofType: .leftEye) {
            for point in leftEyeContour.points {
                let cgPoint = normalizedPoint(fromVisionPoint: point, width: width, height: height)
                UIUtilities.addCircle(
                    atPoint: cgPoint,
                    to: annotationOverlayView,
                    color: UIColor.cyan,
                    radius: Layout.smallDotRadius
                )
            }
        }
        if let rightEyeContour = face.contour(ofType: .rightEye) {
            for point in rightEyeContour.points {
                let cgPoint = normalizedPoint(fromVisionPoint: point, width: width, height: height)
                UIUtilities.addCircle(
                    atPoint: cgPoint,
                    to: annotationOverlayView,
                    color: UIColor.cyan,
                    radius: Layout.smallDotRadius
                )
            }
        }
        
        // Lips
        if let topUpperLipContour = face.contour(ofType: .upperLipTop) {
            for point in topUpperLipContour.points {
                let cgPoint = normalizedPoint(fromVisionPoint: point, width: width, height: height)
                UIUtilities.addCircle(
                    atPoint: cgPoint,
                    to: annotationOverlayView,
                    color: UIColor.red,
                    radius: Layout.smallDotRadius
                )
            }
        }
        if let bottomUpperLipContour = face.contour(ofType: .upperLipBottom) {
            for point in bottomUpperLipContour.points {
                let cgPoint = normalizedPoint(fromVisionPoint: point, width: width, height: height)
                UIUtilities.addCircle(
                    atPoint: cgPoint,
                    to: annotationOverlayView,
                    color: UIColor.red,
                    radius: Layout.smallDotRadius
                )
            }
        }
        if let topLowerLipContour = face.contour(ofType: .lowerLipTop) {
            for point in topLowerLipContour.points {
                let cgPoint = normalizedPoint(fromVisionPoint: point, width: width, height: height)
                UIUtilities.addCircle(
                    atPoint: cgPoint,
                    to: annotationOverlayView,
                    color: UIColor.red,
                    radius: Layout.smallDotRadius
                )
            }
        }
        if let bottomLowerLipContour = face.contour(ofType: .lowerLipBottom) {
            for point in bottomLowerLipContour.points {
                let cgPoint = normalizedPoint(fromVisionPoint: point, width: width, height: height)
                UIUtilities.addCircle(
                    atPoint: cgPoint,
                    to: annotationOverlayView,
                    color: UIColor.red,
                    radius: Layout.smallDotRadius
                )
            }
        }
        
        // Nose
        if let noseBridgeContour = face.contour(ofType: .noseBridge) {
            for point in noseBridgeContour.points {
                let cgPoint = normalizedPoint(fromVisionPoint: point, width: width, height: height)
                UIUtilities.addCircle(
                    atPoint: cgPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Layout.smallDotRadius
                )
            }
        }
        if let noseBottomContour = face.contour(ofType: .noseBottom) {
            for point in noseBottomContour.points {
                let cgPoint = normalizedPoint(fromVisionPoint: point, width: width, height: height)
                UIUtilities.addCircle(
                    atPoint: cgPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Layout.smallDotRadius
                )
            }
        }
    }
    
    /// Resets any detector instances which use a conventional lifecycle paradigm. This method is
    /// expected to be invoked on the AVCaptureOutput queue - the same queue on which detection is
    /// run.
    func resetManagedLifecycleDetectors(activeDetector: DetectorType) {
        if activeDetector == self.lastDetector {
            // Same row as before, no need to reset any detectors.
            return
        }
        self.lastDetector = activeDetector
    }
    
    func rotate(_ view: UIView, orientation: UIImage.Orientation) {
        var degree: CGFloat = 0.0
        switch orientation {
        case .up, .upMirrored:
            degree = 90.0
        case .rightMirrored, .left:
            degree = 180.0
        case .down, .downMirrored:
            degree = 270.0
        case .leftMirrored, .right:
            degree = 0.0
        @unknown default:
            break
        }
        view.transform = CGAffineTransform.init(rotationAngle: degree * 3.141592654 / 180)
    }
}
