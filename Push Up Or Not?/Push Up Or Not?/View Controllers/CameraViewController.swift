//
//  CameraViewController.swift
//  Push Up Or Not?
//
//  Created by Kenny Yu on 9/10/20.
//  Copyright © 2020 Kenny Yu. All rights reserved.
//

import UIKit
import AVFoundation
import CoreVideo
import MLKit
import FirebaseAuth
import Firebase
import SwiftSpinner

class CameraViewController: UIViewController {
    
    // MARK: Setting Up Detector
    
    // List of detectors to be used
    private let detectors: [Detector] = [
        .poseFast,
        .poseAccurate
    ]
    
    // Use fast pose detector as default
    private var currentDetector: Detector = .poseAccurate
    
    // Start off using front camera 
    private var isUsingFrontCamera = false
    
    // Tracks count of reps and alignment
    private var reps = 0
    private var align = false
    private var up = false
    
    // Instance variables for video capture
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private lazy var captureSession = AVCaptureSession()
    private lazy var sessionQueue = DispatchQueue(label: Constant.sessionQueueLabel)
    private var lastFrame: CMSampleBuffer?
    
    private lazy var previewOverlayView: UIImageView = {

        precondition(isViewLoaded)
        let previewOverlayView = UIImageView(frame: .zero)
        previewOverlayView.contentMode = UIView.ContentMode.scaleAspectFill
        previewOverlayView.translatesAutoresizingMaskIntoConstraints = false
        return previewOverlayView
    }()

    private lazy var annotationOverlayView: UIView = {
        precondition(isViewLoaded)
        let annotationOverlayView = UIView(frame: .zero)
        annotationOverlayView.translatesAutoresizingMaskIntoConstraints = false
        return annotationOverlayView
    }()
    
    // MARK: IBOutlet
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var pushUpLabel: UILabel!
    @IBOutlet weak var alignOne: UILabel!
    @IBOutlet weak var alignTwo: UILabel!
    @IBOutlet weak var upOrDown: UILabel!
    @IBOutlet weak var elbowSuggestion: UILabel!
    @IBOutlet weak var repCount: UILabel!
    @IBAction func changeCamera(_ sender: UIBarButtonItem) {
        isUsingFrontCamera = !isUsingFrontCamera
        removeDetectionAnnotations()
        setUpCaptureSessionInput()
    }
    @IBOutlet weak var sign: UIBarButtonItem!
    @IBAction func signButton(_ sender: UIBarButtonItem) {
        if Auth.auth().currentUser?.email == nil {
            
            // Programmatically show second view controller
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let secondVC = storyboard.instantiateViewController(identifier: "SignUpViewController")
            secondVC.modalPresentationStyle = .fullScreen
            secondVC.modalTransitionStyle = .crossDissolve
            present(secondVC, animated: true, completion: nil)
        } else {
            // Show the spinner
            SwiftSpinner.show("Signing Out...")
            
            // Sign user out
            let firebaseAuth = Auth.auth()
            do {
                try firebaseAuth.signOut()
                print("Signed Out")
                
                // Programmatically show second view controller
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let secondVC = storyboard.instantiateViewController(identifier: "NavigationViewController")
                secondVC.modalPresentationStyle = .fullScreen
                secondVC.modalTransitionStyle = .crossDissolve
                
                // Hide spinner and relaunch page
                SwiftSpinner.hide(){
                    self.present(secondVC, animated: true, completion: nil)
                }
            } catch let signOutError as NSError {
                // Create alert controller for error
                let errorAlert = UIAlertController(title: "Error", message: signOutError.localizedDescription, preferredStyle: .alert)
                let errorAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
                
                // Add the action to the alert
                errorAlert.addAction(errorAction)
                                
                // Show to the user
                SwiftSpinner.hide(){
                    self.present(errorAlert, animated: true, completion: nil)
                }

            }
        }
    }
    
    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        pushUpLabel.layer.zPosition = 1
        alignOne.layer.zPosition = 1
        alignTwo.layer.zPosition = 1
        upOrDown.layer.zPosition = 1
        elbowSuggestion.layer.zPosition = 1
        repCount.layer.zPosition = 1
        
        // Set up the camera and live camera feed
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        setUpPreviewOverlayView()
        setUpAnnotationOverlayView()
        setUpCaptureSessionOutput()
        setUpCaptureSessionInput()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // try to sign in anonymously
        let firebaseAuth = Auth.auth()
        
        // check if there is a user
        if firebaseAuth.currentUser == nil {
            sign?.title = "Sign Up"
            firebaseAuth.signInAnonymously { (authResult, error) in
                if let error = error {
                    print(error.localizedDescription)
                    return
                }
            }
        } else if firebaseAuth.currentUser != nil && (firebaseAuth.currentUser?.email == nil) {
            sign?.title = "Sign Up"
        } else if firebaseAuth.currentUser != nil && (firebaseAuth.currentUser?.email != nil) {
            sign?.title = "Sign Out"
            
        }

        // Start the capture session
        startSession()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Once the view is offscreen, end the capture session
        stopSession()
    }

    override func viewDidLayoutSubviews() {
      super.viewDidLayoutSubviews()
        
        // correctly set the frame of the preview layer
        previewLayer.frame = cameraView.frame
    }
    
    // MARK: Current Position/Angle
    var rightElbow: CGFloat = 180.0
    var leftElbow: CGFloat = 180.0
    
    // MARK: Detecting Pose
    private let poseDetectorQueue = DispatchQueue(label: "com.google.mlkit.pose")
    private var _poseDetector: PoseDetector? = nil
    
    // try to get the pose detector and set the detector to be used
    private var poseDetector: PoseDetector? {
        get {
            var detector: PoseDetector? = nil
            poseDetectorQueue.sync {
                if _poseDetector == nil {
                    let options = PoseDetectorOptions()
                    options.detectorMode = .stream
                    options.performanceMode = (currentDetector == .poseFast ? .fast : .accurate);
                    _poseDetector = PoseDetector.poseDetector(options: options)
                }
                detector = _poseDetector
            }
            return detector
        }
        set(newDetector) {
            poseDetectorQueue.sync {
                _poseDetector = newDetector
            }
        }
    }
    
    // Start the pose detection once the app starts
    private func detectPose(in image: VisionImage, width: CGFloat, height: CGFloat) {
        if let poseDetector = self.poseDetector {
        
            // Try to get poses
            var poses: [Pose]
            do {
                poses = try poseDetector.results(in: image)
            } catch let error {
                print("Failed to detect poses with error: \(error.localizedDescription).")
                return
            }
        
            DispatchQueue.main.sync {
                self.updatePreviewOverlayView()
                self.removeDetectionAnnotations()
            }
        
            // If there is no error and you end up getting no poses seen
            guard !poses.isEmpty else {
                // print("Pose detector returned no results.")
                return
            }
        
            // Start a main
            DispatchQueue.main.sync {
                // Pose detected. Currently, only single person detection is supported.
                poses.forEach { pose in
                    for (startLandmarkType, endLandmarkTypesArray) in UIUtilities.poseConnections() {
                        let startLandmark = pose.landmark(ofType: startLandmarkType)
              
                        for endLandmarkType in endLandmarkTypesArray {
                            let endLandmark = pose.landmark(ofType: endLandmarkType)
                            let startLandmarkPoint = normalizedPoint(fromVisionPoint: startLandmark.position, width: width, height: height)
                            let endLandmarkPoint = normalizedPoint(fromVisionPoint: endLandmark.position, width: width, height: height)
      
                            UIUtilities.addLineSegment(
                                fromPoint: startLandmarkPoint,
                                toPoint: endLandmarkPoint,
                                inView: self.annotationOverlayView,
                                color: UIColor.green,
                                width: Constant.lineWidth)
                        }
                    }
            
                    // for each body point detected, add a circle to mark position
                    for landmark in pose.landmarks {
                        let landmarkPoint = normalizedPoint(
                            fromVisionPoint: landmark.position, width: width, height: height)
                            UIUtilities.addCircle(
                                atPoint: landmarkPoint,
                                to: self.annotationOverlayView,
                                color: UIColor.blue,
                                radius: Constant.smallDotRadius)
                    }
              
                    // Get angles of knees and hips
                    let rightHipAngle = angle(
                        firstLandmark: pose.landmark(ofType: .rightShoulder),
                        midLandmark: pose.landmark(ofType:  .rightHip),
                        lastLandmark: pose.landmark(ofType: .rightKnee))
                    let leftHipAngle = angle(
                        firstLandmark: pose.landmark(ofType: .leftShoulder),
                        midLandmark: pose.landmark(ofType: .leftHip),
                        lastLandmark: pose.landmark(ofType: .leftKnee))
                    let rightKneeAngle = angle(
                        firstLandmark: pose.landmark(ofType: .rightHip),
                        midLandmark: pose.landmark(ofType: .rightKnee),
                        lastLandmark: pose.landmark(ofType: .rightAnkle))
                    let leftKneeAngle = angle(
                        firstLandmark: pose.landmark(ofType: .leftHip),
                        midLandmark: pose.landmark(ofType: .leftKnee),
                        lastLandmark: pose.landmark(ofType: .leftAnkle))
            
                    alignment(
                        rightHipAngle: rightHipAngle,
                        leftHipAngle: leftHipAngle,
                        rightKneeAngle: rightKneeAngle,
                        leftKneeAngle: leftKneeAngle)
              
                    // Get the angles of the the elbows
                    let rightElbowAngle = angle(
                        firstLandmark: pose.landmark(ofType: .rightShoulder),
                        midLandmark: pose.landmark(ofType: .rightElbow),
                        lastLandmark: pose.landmark(ofType: .rightWrist))
                    let leftElbowAngle = angle(
                        firstLandmark: pose.landmark(ofType: .leftShoulder),
                        midLandmark: pose.landmark(ofType: .leftElbow),
                        lastLandmark: pose.landmark(ofType: .leftWrist))
            
                    downOrUp(rightElbowAngle: rightElbowAngle, leftElbowAngle: leftElbowAngle)
                }
            }
        }
    }
    
    private func normalizedPoint(fromVisionPoint point: VisionPoint, width: CGFloat, height: CGFloat) -> CGPoint {
      let cgPoint = CGPoint(x: point.x, y: point.y)
      var normalizedPoint = CGPoint(x: cgPoint.x / width, y: cgPoint.y / height)
      normalizedPoint = previewLayer.layerPointConverted(fromCaptureDevicePoint: normalizedPoint)
      return normalizedPoint
    }
    
    // finds the angle between the body parts
    private func angle(firstLandmark: PoseLandmark, midLandmark: PoseLandmark, lastLandmark: PoseLandmark) -> CGFloat {
        
        // get the angle of the positions using degrees
        let radians: CGFloat = atan2(lastLandmark.position.y - midLandmark.position.y, lastLandmark.position.x - midLandmark.position.x) - atan2(firstLandmark.position.y - midLandmark.position.y, firstLandmark.position.x - midLandmark.position.x)
        var degrees = radians * 180.0 / .pi
        degrees = abs(degrees)
        
        // Get acute representation of the angle
        if degrees > 180.0 {
            degrees = 360.0 - degrees
        }
        
        return degrees
    }
    
    // gets the angles of hips and knees for alignment
    private func alignment(rightHipAngle: CGFloat, leftHipAngle: CGFloat, rightKneeAngle: CGFloat, leftKneeAngle: CGFloat) {
        // Boolean for correct posture
        var rightHipStraight = false
        var leftHipStraight = false
        var rightKneeStraight = false
        var leftKneeStraight = false
          
          // Check right hip angle
        if rightHipAngle >= 120.0 && rightHipAngle <= 180.0 {
            rightHipStraight = true
        }
          
        // Check left hip angle
        if leftHipAngle >= 120.0 && leftHipAngle <= 180.0 {
            leftHipStraight = true
        }
          
        // Check right knee angle
        if rightKneeAngle >= 160.0 && rightKneeAngle <= 180.0 {
            rightKneeStraight = true
        }
          
        // Check left knee angle
        if leftKneeAngle >= 160.0 && leftKneeAngle <= 180.0 {
            leftKneeStraight = true
        }
        
        // Check for booleans for what to print
        if !rightKneeStraight || !leftKneeStraight || !rightHipStraight || !leftHipStraight {
            
            // Check if knees are misaligned
            if !rightKneeStraight || !leftKneeStraight {
                self.alignTwo?.text = "Straighten your knees!"
            }
            
            // Maybe it could be hip alignment
            if !rightHipStraight || !leftHipStraight {
                self.alignOne?.text = "Bring your hips in line!"
            }
            
            // Either way, bad push up
            self.pushUpLabel?.text = "Careful, your form is off"
            align = false
            
        } else {
            
            // Since not out of line, compliment form!
            self.alignOne?.text = ""
            self.alignTwo?.text = ""
            self.pushUpLabel?.text = "Nice form!"
            align = true
        }
    }
    
    // gets the angles of the elbows and prints
    private func downOrUp(rightElbowAngle: CGFloat, leftElbowAngle: CGFloat) {
        
        // compare the previous values of elbow angle to the current
        if ((rightElbowAngle - rightElbow) > 10 || (leftElbowAngle - leftElbow) > 10) && align {
            
            // Since detected going up, don't need suggestions
            self.upOrDown?.text = "Detected: Going Up"
            self.elbowSuggestion?.text = ""
            
            // Check if it's a switch from down to up
            if (!up) {
                up = true
                if (align) {
                    reps += 1
                    self.repCount?.text = "Count: " + String(reps)
                    print(reps)
                }
            }
            
        } else if ((rightElbow - rightElbowAngle) > 10 || (leftElbow - leftElbowAngle) > 10) && align {
            self.upOrDown?.text = "Detected: Going Down"
            
            // Since it's going down, check if it's at least 90
            if (rightElbowAngle > 90.0) {
                self.elbowSuggestion?.text = "Keep going until your elbows are at least 90 deg"
            } else {
                self.elbowSuggestion?.text = "Good Job!"
            }
            
            // If it was up before, change it to down
            if (up) {
                up = false
            }
        } else if !align {
            self.upOrDown?.text = ""
            self.elbowSuggestion?.text = ""
        }
        
        // set the new previous values of the elbow angle
        rightElbow = rightElbowAngle
        leftElbow = leftElbowAngle
    }
    
    // MARK: - Private
    private func setUpCaptureSessionOutput() {
        sessionQueue.async {
            self.captureSession.beginConfiguration()
            // When performing latency tests to determine ideal capture settings,
            // run the app in 'release' mode to get accurate performance metrics
            self.captureSession.sessionPreset = AVCaptureSession.Preset.medium

            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [
                (kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA,
            ]
            output.alwaysDiscardsLateVideoFrames = true
            let outputQueue = DispatchQueue(label: Constant.videoDataOutputQueueLabel)
            output.setSampleBufferDelegate(self, queue: outputQueue)
            guard self.captureSession.canAddOutput(output) else {
                print("Failed to add capture session output.")
                return
            }
            self.captureSession.addOutput(output)
            self.captureSession.commitConfiguration()
        }
    }

    private func setUpCaptureSessionInput() {
        sessionQueue.async {
            let cameraPosition: AVCaptureDevice.Position = self.isUsingFrontCamera ? .front : .back
            guard let device = self.captureDevice(forPosition: cameraPosition) else {
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

    
    private func startSession() {
        sessionQueue.async {
            self.captureSession.startRunning()
        }
    }

    private func stopSession() {
        sessionQueue.async {
            self.captureSession.stopRunning()
        }
    }

    private func setUpPreviewOverlayView() {
        cameraView.addSubview(previewOverlayView)
        NSLayoutConstraint.activate([
            previewOverlayView.centerXAnchor.constraint(equalTo: cameraView.centerXAnchor),
            previewOverlayView.centerYAnchor.constraint(equalTo: cameraView.centerYAnchor),
            previewOverlayView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor),
            previewOverlayView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor),
        ])
    }

    private func setUpAnnotationOverlayView() {
        cameraView.addSubview(annotationOverlayView)
        NSLayoutConstraint.activate([
            annotationOverlayView.topAnchor.constraint(equalTo: cameraView.topAnchor),
            annotationOverlayView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor),
            annotationOverlayView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor),
            annotationOverlayView.bottomAnchor.constraint(equalTo: cameraView.bottomAnchor),
        ])
    }

    private func captureDevice(forPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if #available(iOS 10.0, *) {
            let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified)
            return discoverySession.devices.first { $0.position == position }
        }
        return nil
    }

    private func presentDetectorsAlertController() {
        let alertController = UIAlertController(
            title: Constant.alertControllerTitle,
            message: Constant.alertControllerMessage,
            preferredStyle: .alert)
        detectors.forEach { detectorType in
            let action = UIAlertAction(title: detectorType.rawValue, style: .default) {
                [unowned self] (action) in
                guard let value = action.title else { return }
                guard let detector = Detector(rawValue: value) else { return }
                self.currentDetector = detector
                self.removeDetectionAnnotations()

            // Reset the pose detector to `nil` when a new detector row is chosen. The detector will be
            // re-initialized via its getter when it is needed for detection again.
            self.poseDetector = nil
        }
        if detectorType.rawValue == currentDetector.rawValue { action.isEnabled = false }
          alertController.addAction(action)
        }
        alertController.addAction(UIAlertAction(title: Constant.cancelActionTitleText, style: .cancel))
        present(alertController, animated: true)
    }

    private func removeDetectionAnnotations() {
        for annotationView in annotationOverlayView.subviews {
            annotationView.removeFromSuperview()
        }
    }

    private func updatePreviewOverlayView() {
        guard let lastFrame = lastFrame,
            let imageBuffer = CMSampleBufferGetImageBuffer(lastFrame)
        else {
            return
        }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return
        }
        let rotatedImage = UIImage(cgImage: cgImage, scale: Constant.originalScale, orientation: .right)
        if isUsingFrontCamera {
            guard let rotatedCGImage = rotatedImage.cgImage else {
                return
        }
        let mirroredImage = UIImage(
            cgImage: rotatedCGImage, scale: Constant.originalScale, orientation: .leftMirrored)
            previewOverlayView.image = mirroredImage
        } else {
            previewOverlayView.image = rotatedImage
        }
    }

    private func convertedPoints(
        from points: [NSValue]?,
        width: CGFloat,
        height: CGFloat
    ) -> [NSValue]? {
        return points?.map {
            let cgPointValue = $0.cgPointValue
            let normalizedPoint = CGPoint(x: cgPointValue.x / width, y: cgPointValue.y / height)
            let cgPoint = previewLayer.layerPointConverted(fromCaptureDevicePoint: normalizedPoint)
            let value = NSValue(cgPoint: cgPoint)
            return value
        }
    }
}

// MARK: AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
        ) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to get image buffer from sample buffer.")
            return
        }
        lastFrame = sampleBuffer
        let visionImage = VisionImage(buffer: sampleBuffer)
        let orientation = UIUtilities.imageOrientation(
            fromDevicePosition: isUsingFrontCamera ? .front : .back
        )

        visionImage.orientation = orientation
        let imageWidth = CGFloat(CVPixelBufferGetWidth(imageBuffer))
        let imageHeight = CGFloat(CVPixelBufferGetHeight(imageBuffer))

        switch currentDetector {
            case .poseFast, .poseAccurate: detectPose(in: visionImage, width: imageWidth, height: imageHeight)
        }
    }
}


public enum Detector: String {
    case poseAccurate = "Pose, accurate"
    case poseFast = "Pose, fast"
}

private enum Constant {
    static let alertControllerTitle = "Vision Detectors"
    static let alertControllerMessage = "Select a detector"
    static let cancelActionTitleText = "Cancel"
    static let videoDataOutputQueueLabel = "com.google.mlkit.visiondetector.VideoDataOutputQueue"
    static let sessionQueueLabel = "com.google.mlkit.visiondetector.SessionQueue"
    static let noResultsMessage = "No Results"
    static let localModelFile = (name: "bird", type: "tflite")
    static let labelConfidenceThreshold: Float = 0.75
    static let smallDotRadius: CGFloat = 4.0
    static let lineWidth: CGFloat = 3.0
    static let originalScale: CGFloat = 1.0
    static let padding: CGFloat = 10.0
    static let resultsLabelHeight: CGFloat = 200.0
    static let resultsLabelLines = 5
}
