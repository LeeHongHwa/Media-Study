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

class CameraViewController: UIViewController {
    
    var focusMarkerImageView: UIImageView!
    var exposureMarkerImageView: UIImageView!
    var resetMarkerImageView: UIImageView!
    private var adjustingExposureContext: String = ""
    
    @IBOutlet weak var cameraPreview: UIView!
    @IBOutlet weak var thumbnailButton: UIButton!
    @IBOutlet weak var flashLabel: UILabel!
    
    let captureSession = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer!
    var activeInput: AVCaptureDeviceInput!
    let imageOutput = AVCaptureStillImageOutput()
    
    let videoQueue: DispatchQueue = {
        return DispatchQueue.global(qos: .default)
    }()
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSession()
        setupPreview()
        startSession()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - Setup session and preview
    func setupSession() {
        captureSession.sessionPreset = .high
        guard let camera = AVCaptureDevice.default(for: .video) else { return }
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            guard captureSession.canAddInput(input) else { return }
            captureSession.addInput(input)
            activeInput = input
        } catch {
            print("Error setting device input: \(error.localizedDescription)")
        }
        
        imageOutput.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
        
        guard captureSession.canAddOutput(imageOutput) else { return }
        captureSession.addOutput(imageOutput)
    }
    
    func setupPreview() {
        // Configure previewLayer
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = cameraPreview.bounds
        previewLayer.videoGravity = .resizeAspectFill
        cameraPreview.layer.addSublayer(previewLayer)
        
        let testLayer = CALayer()
        testLayer.contents = #imageLiteral(resourceName: "Penguin_1").cgImage
        testLayer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        
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
        focusMarkerImageView = imageViewWithImage(name: "Focus_Point")
        exposureMarkerImageView = imageViewWithImage(name: "Exposure_Point")
        resetMarkerImageView = imageViewWithImage(name: "Reset_Point")
        cameraPreview.addSubview(focusMarkerImageView)
        cameraPreview.addSubview(exposureMarkerImageView)
        cameraPreview.addSubview(resetMarkerImageView)
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
    @IBAction func didTapSwitchCameraButton(_ sender: UIButton) {
        guard !AVCaptureDevice.devices(for: .video).isEmpty else { return }
        let newPoistion: AVCaptureDevice.Position
        if activeInput.device.position == .back {
            newPoistion = .front
        } else {
            newPoistion = .back
        }
        
        var newCamera: AVCaptureDevice?
        let devices = AVCaptureDevice.devices(for: .video)
        
        for device in devices {
            if device.position == newPoistion {
                newCamera = device
            }
        }
        
        if let newCamera = newCamera {
            do {
                let input = try AVCaptureDeviceInput(device: newCamera)
                captureSession.beginConfiguration()
                captureSession.removeInput(activeInput)
                
                if captureSession.canAddInput(input) {
                    captureSession.addInput(input)
                    activeInput = input
                } else {
                    captureSession.addInput(activeInput)
                }
                captureSession.commitConfiguration()
            } catch {
                print("[Error Switch Camera]: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: Focus Methods
    func focus(at point: CGPoint) {
        let device = activeInput.device
        guard device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) else { return }
        do {
            try device.lockForConfiguration()
            device.focusPointOfInterest = point
            device.focusMode = .autoFocus
            device.unlockForConfiguration()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    @objc func tapToFocus(_ recognizer: UIGestureRecognizer) {
        guard activeInput.device.isFocusPointOfInterestSupported else { return }
        let point = recognizer.location(in: cameraPreview)
        let pointOfInterest = previewLayer.captureDevicePointConverted(fromLayerPoint: point)
        showMarkerAtPoint(point: point, marker: focusMarkerImageView)
        focus(at: pointOfInterest)
    }
    
    // MARK: Exposure Methods
    func expose(at point: CGPoint) {
        let device = activeInput.device
        guard device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.continuousAutoExposure) else { return }
        do {
            try device.lockForConfiguration()
            device.exposurePointOfInterest = point
            device.exposureMode = .continuousAutoExposure
            
            guard device.isExposureModeSupported(.locked) else { return }
            device.addObserver(self,
                               forKeyPath: "adjustingExposure",
                               options: .new,
                               context: &adjustingExposureContext)
            device.unlockForConfiguration()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    @objc func tapToExpose(_ recognizer: UIGestureRecognizer) {
        guard activeInput.device.isFocusPointOfInterestSupported else { return }
        let point = recognizer.location(in: cameraPreview)
        let pointOfInterest = previewLayer.captureDevicePointConverted(fromLayerPoint: point)
        showMarkerAtPoint(point: point, marker: exposureMarkerImageView)
        expose(at: pointOfInterest)
    }
    
    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
        guard context == &adjustingExposureContext, let device = object as? AVCaptureDevice else { return }
        if device.isAdjustingExposure, device.isExposureModeSupported(.locked) {
            (object as! NSObject).removeObserver(self, forKeyPath: "adjustingExposure")
            DispatchQueue.main.async {
                do {
                    try device.lockForConfiguration()
                    device.exposureMode = .locked
                    device.unlockForConfiguration()
                } catch {
                    print(error.localizedDescription)
                }
            }
        } else {
            super.observeValue(forKeyPath: keyPath,
                               of: object,
                               change: change,
                               context: context)
        }
    }
    
    // MARK: Reset Focus and Exposure
    @objc func resetFocusAndExposure() {
        let device = activeInput.device
        
        let focusMode = AVCaptureDevice.FocusMode.autoFocus
        let exposureMode = AVCaptureDevice.ExposureMode.autoExpose
        
        let canResetFocus = device.isFocusPointOfInterestSupported &&
            device.isFocusModeSupported(focusMode)
        let canResetExposure = device.isExposurePointOfInterestSupported &&
            device.isExposureModeSupported(exposureMode)
        
        do {
            if canResetFocus && canResetExposure {
                let markerCenter = cameraPreview.center
                
                let center = previewLayer.captureDevicePointConverted(fromLayerPoint: markerCenter)
                showMarkerAtPoint(point: markerCenter, marker: resetMarkerImageView)
                
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
            }
        } catch {
            print("Error resetting focus & exposure: \(error)")
        }
    }
    
    // MARK: Flash Modes
    @IBAction func didTapFlashModeButton(_ sender: UIButton) {
        do {
            let device = activeInput.device
            guard device.hasFlash else { return }
            try device.lockForConfiguration()
            switch device.flashMode {
            case .off:
                device.flashMode = .on
            case .on:
                device.flashMode = .off
            case .auto:
                device.flashMode = .off
            }
            device.unlockForConfiguration()
        } catch {
            print("Error resetting focus & exposure: \(error)")
        }
    }
    
    // MARK: - Capture photo
    @IBAction func didTapCapturePhotoButton(_ sender: UIButton) {
        let connection = imageOutput.connection(with: .video)
        guard connection?.isVideoOrientationSupported ?? false else { return }
        imageOutput.captureStillImageAsynchronously(from: connection!,
                                                    completionHandler: { [weak self] buffer, error in
                                                        guard let weakSelf = self,
                                                            let buffer = buffer,
                                                            let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(buffer),
                                                            let image = UIImage(data: imageData),
                                                            let photoBomb = weakSelf.penguinPhotoBomb(image: image) else { return }

                                                        weakSelf.savePhotoToLibrary(image: photoBomb)
                                                        
        })
    }
    
    // MARK: - Helpers
    func savePhotoToLibrary(image: UIImage) {
        let photoLibrary = PHPhotoLibrary.shared()
        photoLibrary.performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }, completionHandler: { success, error -> Void in
            if success {
                self.setPhotoThumbnail(image)
            } else {
                print("[Error writing to photo library]: \(error!.localizedDescription)")
            }
        })
    }
    
    func setPhotoThumbnail(_ image: UIImage) {
        DispatchQueue.main.async {
            self.thumbnailButton.setBackgroundImage(image, for: .normal)
            self.thumbnailButton.layer.borderColor = UIColor.white.cgColor
            self.thumbnailButton.layer.borderWidth = 1.0
        }
    }
    //찍은 이미지 + 펭귄 이미지
    func penguinPhotoBomb(image: UIImage) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(image.size, true, 0.0)
        image.draw(at: CGPoint(x: 0, y: 0))
        
        // Composite Penguin
        let penguinImage = UIImage(named: "Penguin_\(randomInt(n: 4))")
        
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
    
    func imageViewWithImage(name: String) -> UIImageView {
        let view = UIImageView()
        let image = UIImage(named: name)
        view.image = image
        view.sizeToFit()
        view.isHidden = true
        
        return view
    }
    
    func showMarkerAtPoint(point: CGPoint, marker: UIImageView) {
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
        if segue.identifier == "QuickLookSegue" {
            let quickLook = segue.destination as! QuickLookViewController
            if let image = thumbnailButton.backgroundImage(for: .normal) {
                quickLook.photoImage = image
            } else {
                quickLook.photoImage = UIImage(named: "Penguin")
            }
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
    
    func randomInt(n: Int) -> Int {
        return Int(arc4random_uniform(UInt32(n)))
    }
}

