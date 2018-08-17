//
//  ViewController.swift
//  GPUImageRecorderSample
//
//  Created by kakao on 2018. 8. 17..
//  Copyright © 2018년 lyhonghwa. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import GPUImage2
import AVKit
import Photos

class ViewController: UIViewController {
    
    enum RGB {
        case red
        case green
        case blue
    }
    
    typealias RGBType = (type: RGB, value: Float)
    
    @IBOutlet weak var renderView: RenderView!
    @IBOutlet weak var redSlider: UISlider!
    @IBOutlet weak var greenSlider: UISlider!
    @IBOutlet weak var blueSlider: UISlider!
    @IBOutlet weak var saturationSlider: UISlider!
    
    var camera: Camera!
    var rgbFilter: RGBAdjustment!
    var saturationFilter: SaturationAdjustment!
    var isRecording = false
    var movieOutput: MovieOutput? = nil
    
    var disposeBag: DisposeBag! = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            camera = try Camera(sessionPreset:.vga640x480)
            camera.runBenchmark = true
            rgbFilter = RGBAdjustment()
            saturationFilter = SaturationAdjustment()
            camera --> rgbFilter --> saturationFilter --> renderView
//            camera --> rgbFilter --> saturationFilter --> renderView
            camera.startCapture()
        } catch {
            fatalError("Could not initialize rendering pipeline: \(error)")
        }
        
        let red = redSlider.rx.value.map { value -> RGBType in (RGB.red, value) }
        let green = greenSlider.rx.value.map { value -> RGBType in (RGB.green, value) }
        let blue = blueSlider.rx.value.map { value -> RGBType in  (RGB.blue, value) }
        
        Observable<RGBType>.merge([red, green, blue])
            .subscribe (onNext: { [weak self] data in
                guard let weakSelf = self else { return }
                switch data.type {
                case .red:
                    weakSelf.rgbFilter.red = data.value
                case .green:
                    weakSelf.rgbFilter.green = data.value
                case .blue:
                    weakSelf.rgbFilter.blue = data.value
                }
            })
            .disposed(by: disposeBag)
        
        saturationSlider.rx.value
            .subscribe (onNext: { [weak self] value in
                guard let weakSelf = self else { return }
                weakSelf.saturationFilter.saturation = value
            })
            .disposed(by: disposeBag)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    @IBAction func didTapCaptureButton(_ sender: UIButton) {
        if (!isRecording) {
            do {
                self.isRecording = true
                let documentsDir = try FileManager.default.url(for:.documentDirectory, in:.userDomainMask, appropriateFor:nil, create:true)
                let fileURL = URL(string:"test.mp4", relativeTo:documentsDir)!
                do {
                    try FileManager.default.removeItem(at:fileURL)
                } catch {
                }
                
                movieOutput = try MovieOutput(URL:fileURL, size:Size(width:480, height:640), liveVideo:true)
                camera.audioEncodingTarget = movieOutput
                rgbFilter --> saturationFilter --> movieOutput!
                movieOutput!.startRecording()
                DispatchQueue.main.async {
                    // Label not updating on the main thread, for some reason, so dispatching slightly after this
                    sender.titleLabel!.text = "Stop"
                }
            } catch {
                fatalError("Couldn't initialize movie, error: \(error)")
            }
        } else {
            movieOutput?.finishRecording{
                do {
                    let documentsDir = try FileManager.default.url(for:.documentDirectory, in:.userDomainMask, appropriateFor:nil, create:true)
                    let fileURL = URL(string:"test.mp4", relativeTo:documentsDir)!
                    self.saveMovieToLibrary(movieURL: fileURL)
                    self.isRecording = false
                    DispatchQueue.main.async {
                        sender.titleLabel!.text = "Record"
                    }
                    self.camera.audioEncodingTarget = nil
                    self.movieOutput = nil
                } catch {
                    
                }
                
            }
        }
    }
    
    private func saveMovieToLibrary(movieURL: URL) {
        let photoLibrary = PHPhotoLibrary.shared()
        photoLibrary.performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: movieURL)
        }, completionHandler: { [weak self] success, error in
            let asset = AVAsset(url: movieURL)
            let playerItem = AVPlayerItem(asset: asset)
            let player = AVPlayer(playerItem: playerItem)
            
            let playerViewController = AVPlayerViewController()
            playerViewController.player = player
            
            self?.present(playerViewController, animated: true) {
                playerViewController.player?.play()
            }
        })
    }
}
