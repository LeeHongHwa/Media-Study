//
//  ViewController.swift
//  PenguinCam
//
//  Created by Michael Briscoe on 1/8/16.
//  Copyright © 2016 Razeware LLC. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

enum CaptureMode: Int {
    case photo, video
    
    var textValue: String {
        switch self {
        case .photo:
            return "Photo"
        case .video:
            return "Video"
        }
    }
}

enum FlashMode: Int {
    case none = -1
    case off = 0
    case on = 1
    case auto = 2
    
    init(rawValue: Int) {
        switch rawValue {
        case -1:
            self = .none
        case 0:
            self = .off
        case 1:
            self = .on
        case 2:
            self = .auto
        default:
            self = .off
        }
    }
    
    var textValue: String {
        switch self {
        case .none:
            return "N/A"
        case .off:
            return "Off"
        case .on:
            return "On"
        case .auto:
            return "Auto"
        }
    }
    
    var nextMode: FlashMode {
        switch self {
        case .none:
            return .none
        case .off:
            return .on
        case .on:
            return .auto
        case .auto:
            return .off
        }
    }
    
    var asFlashMode: AVCaptureDevice.FlashMode {
        switch self {
        case .none:
            return .off
        case .off:
            return .off
        case .on:
            return .on
        case .auto:
            return .auto
        }
    }
    
    var asTouch: AVCaptureDevice.TorchMode {
        switch self {
        case .none:
            return .off
        case .off:
            return .off
        case .on:
            return .on
        case .auto:
            return .auto
        }
    }
}

class ViewController: UIViewController {
    let captureSession = AVCaptureSession()
    let imageOutput: AVCaptureStillImageOutput = {
        let imageOutput = AVCaptureStillImageOutput()
        imageOutput.outputSettings = [AVVideoCodecKey : AVVideoCodecJPEG]
        return imageOutput
    }()
    let movieOutput: AVCaptureMovieFileOutput = {
        let movieOutput = AVCaptureMovieFileOutput()
        return movieOutput
    }()
    var previewLayer: AVCaptureVideoPreviewLayer!
    var activeInput: AVCaptureDeviceInput!
    
    var focusMarker: UIImageView!
    var exposureMarker: UIImageView!
    var resetMarker: UIImageView!
    private var adjustingExposureContext: String = ""
    
    @IBOutlet weak var cameraPreview: UIView!
    @IBOutlet weak var thumbnailButton: UIButton!
    @IBOutlet weak var flashLabel: UILabel!
    @IBOutlet weak var modePickerView: UIPickerView!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var captureButton: UIButton!
    
    var modeData: [CaptureMode] = [.photo, .video]
    var captureMode: CaptureMode = .photo
    
    let videoQueue: DispatchQueue = {
        return DispatchQueue.global(qos: .default)
    }()
    var timer: DispatchSourceTimer?
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    // MARK: - Setup
    override func viewDidLoad() {
        super.viewDidLoad()
        guard setupSession() else { return }
        setupPreview()
        startSession()
        setupCaptureMode(.photo)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - Setup session and preview
    func setupSession() -> Bool {
        captureSession.sessionPreset = .high
        
        // Setup Camera
        do {
            guard let camera = AVCaptureDevice.default(for: .video) else { return  false }
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                activeInput = input
            }
        } catch {
            print("Error setting device video input: \(error)")
            return false
        }
        
        // Setup Microphone
        do {
            guard let microphone = AVCaptureDevice.default(for: .audio) else { return false }
            let micInput = try AVCaptureDeviceInput(device: microphone)
            guard captureSession.canAddInput(micInput) else { return false }
            captureSession.addInput(micInput)
        } catch {
            print(error.localizedDescription)
            return false
        }
        
        // Setup Output
        // Still Image
        if captureSession.canAddOutput(imageOutput) {
            captureSession.addOutput(imageOutput)
        }
        
        // Video
        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
        }
        
        return true
    }
    
    func setupPreview() {
        // Configure previewLayer
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = cameraPreview.bounds
        previewLayer.videoGravity = .resizeAspectFill
        cameraPreview.layer.addSublayer(previewLayer)
        
        // Attach tap recognizer for focus & exposure.
        let tapForFocus = UITapGestureRecognizer(target: self, action: #selector(tapToFocus(_:)))
        tapForFocus.numberOfTapsRequired = 1
        
        let tapForExposure = UITapGestureRecognizer(target: self, action: #selector(tapToExpose(_:)))
        tapForExposure.numberOfTapsRequired = 2
        
        let tapForReset = UITapGestureRecognizer(target: self, action: #selector(resetFocusAndExposure))
        tapForReset.numberOfTapsRequired = 2
        tapForReset.numberOfTouchesRequired = 2
        
        cameraPreview.addGestureRecognizer(tapForFocus)
        cameraPreview.addGestureRecognizer(tapForExposure)
        cameraPreview.addGestureRecognizer(tapForReset)
        tapForFocus.require(toFail: tapForExposure)
        
        // Create marker views.
        focusMarker = imageView(with: "Focus_Point")
        exposureMarker = imageView(with: "Exposure_Point")
        resetMarker = imageView(with: "Reset_Point")
        cameraPreview.addSubview(focusMarker)
        cameraPreview.addSubview(exposureMarker)
        cameraPreview.addSubview(resetMarker)
    }
    
    func startSession() {
        guard !captureSession.isRunning else { return }
        videoQueue.async { [weak self] in
            guard let weakSelf = self else { return }
            weakSelf.captureSession.startRunning()
        }
    }
    
    func stopSession() {
        guard captureSession.isRunning else { return }
        videoQueue.async { [weak self] in
            guard let weakSelf = self else { return }
            weakSelf.captureSession.stopRunning()
        }
    }
    
    // MARK: - Configure
    @IBAction func didTapSwitchCamerasButton(_ sender: UIButton) {
        guard movieOutput.isRecording else { return }
            // Make sure the device has more than 1 camera.
            guard !AVCaptureDevice.devices(for: .video).isEmpty else { return }
            
            // Check which position the active camera is.
            var newPosition: AVCaptureDevice.Position!
            if activeInput.device.position == .back {
                newPosition = .front
            } else {
                newPosition = .back
            }
            
            // Get camera at new position.
            var newCamera: AVCaptureDevice!
            let devices = AVCaptureDevice.devices(for: .video)
            
            for device in devices {
                if device.position == newPosition {
                    newCamera = device
                }
            }
            
            // Create new input and update capture session.
            do {
                let input = try AVCaptureDeviceInput(device: newCamera)
                captureSession.beginConfiguration()
                // Remove input for active camera.
                captureSession.removeInput(activeInput)
                // Add input for new camera.
                if captureSession.canAddInput(input) {
                    captureSession.addInput(input)
                    activeInput = input
                } else {
                    captureSession.addInput(activeInput)
                }
                captureSession.commitConfiguration()
            } catch {
                print("Error switching cameras: \(error)")
            }
    }
    
    // MARK: Focus Methods
    @objc func tapToFocus(_ recognizer: UIGestureRecognizer) {
        guard activeInput.device.isFocusPointOfInterestSupported else { return }
        let point = recognizer.location(in: cameraPreview)
        let pointOfInterest = previewLayer.captureDevicePointConverted(fromLayerPoint: point)
        showMarker(at: point, marker: focusMarker)
        focus(at: pointOfInterest)
    }
    
    func focus(at point: CGPoint) {
        let device = activeInput.device
        // Make sure the device supports focus on POI and Auto Focus.
        guard device.isFocusPointOfInterestSupported &&
            device.isFocusModeSupported(.autoFocus) else { return }
        do {
            try device.lockForConfiguration()
            device.focusPointOfInterest = point
            device.focusMode = .autoFocus
            device.unlockForConfiguration()
        } catch {
            print("Error focusing on POI: \(error)")
        }
    }
    
    // MARK: Exposure Methods
    @objc func tapToExpose(_ recognizer: UIGestureRecognizer) {
        guard activeInput.device.isExposurePointOfInterestSupported else { return }
        let point = recognizer.location(in: cameraPreview)
        let pointOfInterest = previewLayer.captureDevicePointConverted(fromLayerPoint: point)
        showMarker(at: point, marker: exposureMarker)
        expose(at: pointOfInterest)
    }
    
    func expose(at point: CGPoint) {
        let device = activeInput.device
        guard device.isExposurePointOfInterestSupported &&
            device.isExposureModeSupported(.autoExpose) else { return }
        do {
            try device.lockForConfiguration()
            device.exposurePointOfInterest = point
            device.exposureMode = .autoExpose
            
            guard device.isExposureModeSupported(.locked) else { return }
            device.addObserver(self,
                               forKeyPath: "adjustingExposure",
                               options: .new,
                               context: &adjustingExposureContext)
            
            device.unlockForConfiguration()
        } catch {
            print("Error exposing on POI: \(error)")
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
        if context == &adjustingExposureContext {
            guard let device = object as? AVCaptureDevice,
                device.isAdjustingExposure,
                device.isExposureModeSupported(.locked) else { return }
            (object as! NSObject).removeObserver(self, forKeyPath: "adjustingExposure", context: &adjustingExposureContext)
            
            DispatchQueue.main.async {
                do {
                    try device.lockForConfiguration()
                    device.exposureMode = .locked
                    device.unlockForConfiguration()
                } catch {
                    print("Error exposing on POI: \(error)")
                }
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    
    // MARK: Reset Focus and Exposure
    @objc func resetFocusAndExposure() {
        let device = activeInput.device
        let focusMode = AVCaptureDevice.FocusMode.autoFocus
        let exposureMode = AVCaptureDevice.ExposureMode.autoExpose
        
        let canResetFocus = device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode)
        let canResetExposure = device.isFocusPointOfInterestSupported && device.isExposureModeSupported(exposureMode)
        
        let center = CGPoint(x: 0.5, y: 0.5)
        
        if canResetFocus || canResetExposure {
            let markerCenter = previewLayer.layerPointConverted(fromCaptureDevicePoint: center)
            showMarker(at: markerCenter, marker: resetMarker)
        }
        
        do {
            try device.lockForConfiguration()
            if canResetFocus {
                device.focusMode = focusMode
                device.focusPointOfInterest = center
            }
            
            if canResetExposure {
                device.exposureMode = exposureMode
                device.exposurePointOfInterest = center
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Error resetting focus & exposure: \(error)")
        }
    }
    
    // MARK: Flash Modes (Still Photo)
    func setFlashMode(_ mode: FlashMode) {
        let device = activeInput.device
        flashLabel.text = mode.textValue
        guard device.hasFlash,
            device.isFlashModeSupported(mode.asFlashMode) else { return }
        do {
            try device.lockForConfiguration()
            device.flashMode = mode.asFlashMode
            device.unlockForConfiguration()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    // MARK: Torch Modes (Video)
    func setTorchMode(_ mode: FlashMode) {
        let device = activeInput.device
        flashLabel.text = mode.textValue
        guard device.hasTorch,
            device.isTorchModeSupported(mode.asTouch) else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = mode.asTouch
            device.unlockForConfiguration()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    // MARK: - Capture photo
    func capturePhoto() {
        guard let connection = imageOutput.connection(with: .video), connection.isVideoOrientationSupported else { return }
        
        connection.videoOrientation = currentVideoOrientation
        
        imageOutput.captureStillImageAsynchronously(from: connection, completionHandler: { [weak self] buffer, error in
            guard let weakSelf = self,
                let buffer = buffer,
                let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(buffer),
                let image = UIImage(data: imageData),
                let photoBomb = weakSelf.penguinPhotoBomb(image: image) else { return }
            weakSelf.savePhotoToLibrary(image: photoBomb)
        })
    }
    
    func savePhotoToLibrary(image: UIImage) {
        let photoLibrary = PHPhotoLibrary.shared()
        
        photoLibrary.performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }, completionHandler: { [weak self] success, error in
            guard let weakSelf = self,
                success else { print("Error writing to photo library: \(error!.localizedDescription)"); return }
            weakSelf.setPhotoThumbnail(image: image)
        })
    }
    
    func setPhotoThumbnail(image: UIImage) {
        DispatchQueue.main.async { [weak self] in
            guard let weakSelf = self else { return }
            weakSelf.thumbnailButton.setBackgroundImage(image, for: .normal)
            weakSelf.thumbnailButton.layer.borderColor = UIColor.white.cgColor
            weakSelf.thumbnailButton.layer.borderWidth = 1.0
        }
    }
    
    // MARK: - Movie Capture
    func captureMovie() {
        if movieOutput.isRecording {
            movieOutput.stopRecording()
        } else {
            guard let connection = movieOutput.connection(with: .video) else { return }
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = currentVideoOrientation
            }
            
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .auto
            }
            
            let device = activeInput.device
            
            if device.isSmoothAutoFocusSupported {
                do {
                    try device.lockForConfiguration()
                    device.isSmoothAutoFocusEnabled = true
                    device.unlockForConfiguration()
                } catch {
                    print(error.localizedDescription)
                }
            }
            guard let outputURL = tempURL else { return }
            movieOutput.startRecording(to: outputURL, recordingDelegate: self)
        }
    }
    
    func saveMovieToLibrary(movieURL: URL) {
        let photoLibrary = PHPhotoLibrary.shared()
        photoLibrary.performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: movieURL)
        }, completionHandler: { [weak self] success, error in
            guard let weakSelf = self, success else { print("Error writing to movie library: \(error!.localizedDescription)"); return }
            weakSelf.setVideoThumbnailFromURL(movieURL: movieURL)
        })
    }
    
    func setVideoThumbnailFromURL(movieURL: URL) {
        videoQueue.async { [weak self] in
            guard let weakSelf = self else { return }
            let asset = AVAsset(url: movieURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            
            do {
                let imageRef = try imageGenerator.copyCGImage(at: kCMTimeZero, actualTime: nil)
                let image = UIImage(cgImage: imageRef)
                weakSelf.setPhotoThumbnail(image: image)
            } catch {
                print("Error generating image: \(error)")
            }
        }
    }
    
    // MARK: - Helpers
    @IBAction func didTapFlashOrTorchButton(_ sender: UIButton) {
        let nextMode = currentFlashOrTorchMode.nextMode
        switch captureMode {
        case .photo:
            setFlashMode(nextMode)
        case .video:
            setTorchMode(nextMode)
        }
    }
    
    var currentFlashOrTorchMode: FlashMode {
        var currentMode: Int = 0
        switch captureMode {
        case .photo:
            currentMode = activeInput.device.flashMode.rawValue
        case .video:
            currentMode = activeInput.device.torchMode.rawValue
        }
        
        if !activeInput.device.hasFlash {
            currentMode = 0
        }
        
        return FlashMode(rawValue: currentMode)
    }
    
    
    @IBAction func didTapCaptureButton(_ sender: UIButton) {
        switch captureMode {
        case .photo:
            capturePhoto()
        case .video:
            captureMovie()
        }
    }
    
    func setupCaptureMode(_ mode: CaptureMode) {
        captureMode = mode
        switch mode {
        case .photo:
            timeLabel.isHidden = true
        case .video:
            timeLabel.isHidden = false
        }
    }
    
    func penguinPhotoBomb(image: UIImage) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(image.size, true, 0.0)
        image.draw(at: CGPoint(x: 0, y: 0))
        
        // Composite Penguin
        let penguinImage = UIImage(named: "Penguin_\(randomInt(4))")
        
        var xFactor: CGFloat
        if randomFloat(from: 0.0, to: 1.0) >= 0.5 {
            xFactor = randomFloat(from: 0.0, to: 0.25)
        } else {
            xFactor = randomFloat(from: 0.75, to: 1.0)
        }
        
        var yFactor: CGFloat
        if image.size.width < image.size.height {
            yFactor = 0.0
        } else {
            yFactor = 0.35
        }
        
        let penguinX = (image.size.width * xFactor) - (penguinImage!.size.width / 2)
        let penguinY = (image.size.height * 0.5) - (penguinImage!.size.height * yFactor)
        let penguinOrigin = CGPoint(x: penguinX, y: penguinY)
        
        penguinImage?.draw(at: penguinOrigin)
        
        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return finalImage
    }
    
    func imageView(with name: String) -> UIImageView {
        let view = UIImageView()
        let image = UIImage(named: name)
        view.image = image
        view.sizeToFit()
        view.isHidden = true
        
        return view
    }
    
    func showMarker(at point: CGPoint, marker: UIImageView) {
        marker.center = point
        marker.isHidden = false
        
        UIView.animate(withDuration: 0.15,
                       delay: 0.0,
                       options: .curveEaseInOut,
                       animations: {
                        marker.layer.transform = CATransform3DMakeScale(0.5, 0.5, 1.0)
        },
                       completion: { _ in
                        let popTime = DispatchTime.now() + .milliseconds(500)
                        DispatchQueue.main.asyncAfter(deadline: popTime, execute: {
                            marker.isHidden = true
                            marker.transform = .identity
                        })
        })
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard segue.identifier == "QuickLookSegue",
            let quickLook = segue.destination as? QuickLookViewController else { return }
        
        if let image = thumbnailButton.backgroundImage(for: .normal) {
            quickLook.photoImage = image
        } else {
            quickLook.photoImage = UIImage(named: "Penguin")
        }
    }
    
    var currentVideoOrientation: AVCaptureVideoOrientation {
        switch UIDevice.current.orientation {
        case .portrait:
            return .portrait
        case .landscapeRight:
            return .landscapeLeft
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft, .faceUp, .faceDown, .unknown:
            return .landscapeRight
        }
    }
    
    func randomFloat(from: CGFloat, to: CGFloat) -> CGFloat {
        let rand: CGFloat = CGFloat(Float(arc4random()) / 0xFFFFFFFF)
        return (rand) * (to - from) + from
    }
    
    func randomInt(_ n: Int) -> Int {
        return Int(arc4random_uniform(UInt32(n)))
    }
    
    var tempURL: URL? {
        let directory = NSTemporaryDirectory()
        guard !directory.isEmpty else { return nil }
        var pathComponent = "penCam.mov"
        if directory.last != "/" {
            pathComponent = "/\(pathComponent)"
        }
        let path = directory.appending(pathComponent)
        return URL(fileURLWithPath: path)
    }
    
    func formattedCurrentTime(time: UInt) -> String {
        let hours = time / 3600
        let minutes = (time / 60) % 60
        let seconds = time % 60
        
        return String(format: "%02i:%02i:%02i", arguments: [hours, minutes, seconds])
    }
}

// AVCaptureFileOutputRecordingDelegate
extension ViewController: AVCaptureFileOutputRecordingDelegate {
    func startTimer(handler: @escaping () -> Void) {
        timer?.stop()
        timer = nil
        timer = DispatchQueue.global().createTimer(seconds: 1, async: handler)
        timer?.resume()
    }
    
    func stopTimer() {
        timer?.stop()
        timer = nil
        timeLabel.text = formattedCurrentTime(time: 0)
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        startTimer { [weak self] in
            DispatchQueue.main.async {
                guard let weakSelf = self else { return }
                let time = UInt(CMTimeGetSeconds(weakSelf.movieOutput.recordedDuration))
                weakSelf.timeLabel.text = weakSelf.formattedCurrentTime(time: time)
            }
        }
        captureButton.setImage(#imageLiteral(resourceName: "Capture_Butt1"), for: .normal)
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        guard error == nil else { return }
        stopTimer()
        saveMovieToLibrary(movieURL: outputFileURL)
        captureButton.setImage(#imageLiteral(resourceName: "Capture_Butt"), for: .normal)
    }
}

extension ViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return modeData.count
    }
    
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        let titleData = modeData[row].textValue
        let myTitle = NSAttributedString(string: titleData, attributes: [.foregroundColor: UIColor.white])
        return myTitle
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        guard let mode = CaptureMode(rawValue: row) else { return }
        setupCaptureMode(mode)
        switch mode {
        case .photo:
            setFlashMode(.off)
        case .video:
            setTorchMode(.off)
        }
    }
}
