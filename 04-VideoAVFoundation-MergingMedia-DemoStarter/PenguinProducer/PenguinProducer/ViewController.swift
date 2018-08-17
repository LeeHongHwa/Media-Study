//
//  ViewController.swift
//  PenguinProducer
//
//  Created by Michael Briscoe on 1/5/16.
//  Copyright © 2016 Razeware LLC. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit
import MobileCoreServices
import Photos
import MediaPlayer

class ViewController: UIViewController {
    @IBOutlet weak var videoTableView: UITableView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var musicLabel: UILabel!
    
    var imagePickerViewController: UIImagePickerController!
    var videoURLs = [URL]()
    var currentTableIndex = -1
    let HDVideoSize = CGSize(width: 1920, height: 1080)
    var musicAsset: AVAsset?
    var previewURL: URL?
    
    // MARK: - Setup
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @IBAction func didTapAddVideoClipButton(_ sender: UIButton) {
        switch PHPhotoLibrary.authorizationStatus() {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    guard status == .authorized, let weakSelf = self else { return }
                    weakSelf.presentImagePickerViewController()
                }
            }
            
        case .authorized:
            presentImagePickerViewController()
            
        case .denied, .restricted:
            return
        }
    }
    
    private func presentImagePickerViewController() {
        guard !activityIndicator.isAnimating,
            UIImagePickerController.isSourceTypeAvailable(.photoLibrary),
            (UIImagePickerController.availableMediaTypes(for: .photoLibrary)?.contains(kUTTypeMovie as String) ?? false) else { return }
        imagePickerViewController = UIImagePickerController()
        imagePickerViewController.delegate = self
        imagePickerViewController.sourceType = .photoLibrary
        imagePickerViewController.allowsEditing = false
        imagePickerViewController.mediaTypes = [kUTTypeMovie as String]
        imagePickerViewController.videoQuality = .typeHigh
        
        present(imagePickerViewController, animated: true, completion: nil)
    }
    
    func addVideoURL(_ url: URL) {
        videoURLs.append(url)
        videoTableView.reloadData()
        previewURL = nil
    }
    
    @IBAction func didTapDeleteVideoClipButton(_ sender: UIButton) {
        if currentTableIndex != -1 && !activityIndicator.isAnimating {
            let theAlert = UIAlertController(title: "동영상 지우기",
                                             message: "진짜 지울래?",
                                             preferredStyle: .alert)
            
            theAlert.addAction(UIAlertAction(title: "아니오", style: .cancel, handler: nil))
            theAlert.addAction(UIAlertAction(title: "예", style: .destructive, handler: { action in
                self.videoURLs.remove(at: self.currentTableIndex)
                self.videoTableView.reloadData()
                self.currentTableIndex = -1
                self.previewURL = nil
            }))
            
            present(theAlert, animated: true, completion:nil)
            
        }
    }
    
    @IBAction func didTapAddSoundtrackButton(_ sender: UIButton) {
        let mediaPickerController = MPMediaPickerController(mediaTypes: .music)
        mediaPickerController.delegate = self
        mediaPickerController.prompt = "사운드 선택."
        mediaPickerController.showsCloudItems = false
        mediaPickerController.allowsPickingMultipleItems = false
        present(mediaPickerController, animated: true, completion: nil)
    }
    
    // MARK: - Composition Methods
    @IBAction func didTapPreviewCompositionButton(_ sender: UIButton) {
        guard !videoURLs.isEmpty, !activityIndicator.isAnimating else { return }
        let playerItem: AVPlayerItem
        if let previewURL = previewURL {
            playerItem = AVPlayerItem(url: previewURL)
        } else {
            //url을 통해서 asset 얻기
            let videoAssets = videoURLs.map { AVAsset(url: $0) }
            //track을 담을수 있는 composition 생성
            let composition = AVMutableComposition()
            //asset으로 부터 track 생성
            let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
            let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            
            var startTime = kCMTimeZero
            videoAssets.forEach { asset in
                do {
                    if !asset.tracks(withMediaType: .video).isEmpty {
                        let assetVideoTrack = asset.tracks(withMediaType: .video)[0]
                        try videoTrack?.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), of: assetVideoTrack, at: startTime)
                    }
                    
                    if !asset.tracks(withMediaType: .audio).isEmpty {
                        let assetAudioTrack = asset.tracks(withMediaType: .audio)[0]
                        try audioTrack?.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), of: assetAudioTrack, at: startTime)
                    }
                    
                    startTime = CMTimeAdd(startTime, asset.duration)
                } catch {
                    print(error.localizedDescription)
                }
            }
            playerItem = AVPlayerItem(asset: composition)
        }
        
        let playerViewController = AVPlayerViewController()
        playerViewController.player = AVPlayer(playerItem: playerItem)
        
        present(playerViewController, animated: true) {
            playerViewController.player?.play()
        }
    }
    
    @IBAction func didTapMergeAndExportVideoButton(_ sender: UIButton) {
        guard !videoURLs.isEmpty, !activityIndicator.isAnimating else { return }
        let alert = UIAlertController(title: "합치고 내보내기", message: "합치고 내보내기", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "아니오", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "예", style: .destructive, handler: { [weak self] action in
            guard let weakSelf = self else { return }
            weakSelf.activityIndicator.startAnimating()
            weakSelf.previewURL = nil
            
            let videoAssets = weakSelf.videoURLs.map { AVAsset(url: $0) }
            
            let composition = AVMutableComposition()
            let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            
            //AVMutableVideoCompositionInstruction의 역할은 layer instructions들을 모아놓는 역할이다.
            let mainInstruction = AVMutableVideoCompositionInstruction()
            var startTime = kCMTimeZero
            
            videoAssets.forEach { asset in
                do {
                    if !asset.tracks(withMediaType: .video).isEmpty {
                        //layer insturctions는 전 트랙에 걸쳐서 적용되기 때문에 개별로 트랙을 만들어 준다.
                        let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
                        let assetVideoTrack = asset.tracks(withMediaType: .video)[0]
                        try videoTrack?.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), of: assetVideoTrack, at: startTime)
                        if let videoTrack = videoTrack, let instruction = weakSelf.videoCompositionInstruction(for: videoTrack, asset: asset) {
                            
                            if asset == videoAssets.last {
                                instruction.setOpacity(1.0, at: startTime)
                            } else {
                                instruction.setOpacity(0, at: CMTimeAdd(startTime, asset.duration))
                            }
                            mainInstruction.layerInstructions.append(instruction)
                        }
                    }
                    
                    if !asset.tracks(withMediaType: .audio).isEmpty {
                        let assetAudioTrack = asset.tracks(withMediaType: .audio)[0]
                        try audioTrack?.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), of: assetAudioTrack, at: startTime)
                    }
                    
                    startTime = CMTimeAdd(startTime, asset.duration)
                    
                } catch {
                    print(error.localizedDescription)
                }
            }
            let totalDuration = startTime
            do {
                guard let selectedAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid),
                    let musicTrack = weakSelf.musicAsset?.tracks[0] else { return }
              try selectedAudioTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, totalDuration), of: musicTrack, at: kCMTimeZero)
            } catch {
                print(error.localizedDescription)
            }
            mainInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, totalDuration)
            
            //AVMutableVideoComposition의 역할은 많은 비디오 트랙들의 재생과 프레임, 재생시간, rendersize, scale을 설정하는 역할.
            let videoComposition = AVMutableVideoComposition()
            videoComposition.instructions = [mainInstruction]
            videoComposition.frameDuration = CMTimeMake(1, 30)
            videoComposition.renderSize = weakSelf.HDVideoSize
            videoComposition.renderScale = 1.0
            
            guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality), let uniqueURL = weakSelf.uniqueURL else { return }
            exporter.outputURL = uniqueURL
            exporter.outputFileType = .mov
            exporter.shouldOptimizeForNetworkUse = true
            exporter.videoComposition = videoComposition
            
            
            exporter.exportAsynchronously(completionHandler: {
                DispatchQueue.main.async {
                    weakSelf.exportDidFinish(session: exporter)
                }
            })
        }))
        present(alert, animated: true, completion: nil)
    }
    
    func exportDidFinish(session: AVAssetExportSession) {
        if session.status == .completed {
            let outputURL = session.outputURL
            let photoLibrary = PHPhotoLibrary.shared()
            
            photoLibrary.performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL!)
            }, completionHandler: { success, error in
                var alertTitle = ""
                var alertMessage = ""
                if success {
                    alertTitle = "성공!"
                    alertMessage = "라이브러리에 저장 성공!"
                    self.previewURL = session.outputURL
                } else {
                    alertTitle = "실패!"
                    alertMessage = "라이브러리에 저장 실패!"
                    self.previewURL = nil
                }
                
                let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "예", style: .cancel, handler: nil))
                
                DispatchQueue.main.async {
                    self.present(alert, animated: true, completion: nil)
                }
            })
            
            activityIndicator.stopAnimating()
        }
    }
    
    // MARK: - Helpers
    //AVMutableVideoCompositionLayerInstruction 은 scale, cropping, opacity 등을 관리한다.
    func videoCompositionInstruction(for track: AVCompositionTrack, asset: AVAsset) -> AVMutableVideoCompositionLayerInstruction? {
        guard !asset.tracks(withMediaType: .video).isEmpty else { return nil }
        
        let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        let videoTrack = asset.tracks(withMediaType: .video)[0]
        
        let transform = videoTrack.preferredTransform
        let assetInfo = orientation(from: transform)
        
        if assetInfo.isPortrait {
            let scaleToFitRatio = HDVideoSize.height / videoTrack.naturalSize.width
            let scaleFactor = CGAffineTransform(scaleX: scaleToFitRatio, y: scaleToFitRatio)
            let height = videoTrack.preferredTransform.concatenating(scaleFactor)
            let width = CGAffineTransform(translationX: (videoTrack.naturalSize.width * scaleToFitRatio) * 0.6, y: 0)
            let concat = height.concatenating(width)
            
            instruction.setTransform(concat, at: kCMTimeZero)
            
        } else {
            let scaleToFitRatio = HDVideoSize.width / videoTrack.naturalSize.width
            let scaleFactor = CGAffineTransform(scaleX: scaleToFitRatio, y: scaleToFitRatio)
            let concat = videoTrack.preferredTransform.concatenating(scaleFactor)
            
            instruction.setTransform(concat, at: kCMTimeZero)
        }
        
        return instruction
    }
    
    func orientation(from transform: CGAffineTransform) -> (orientation: UIImageOrientation, isPortrait: Bool) {
        var assetOrientation: UIImageOrientation = .up
        var isPortrait = false
        if transform.a == 0 && transform.b == 1.0 && transform.c == -1.0 && transform.d == 0 {
            assetOrientation = .right
            isPortrait = true
        } else if transform.a == 0 && transform.b == -1.0 && transform.c == 1.0 && transform.d == 0 {
            assetOrientation = .left
            isPortrait = true
        } else if transform.a == 1.0 && transform.b == 0 && transform.c == 0 && transform.d == 1.0 {
            assetOrientation = .up
        } else if transform.a == -1.0 && transform.b == 0 && transform.c == 0 && transform.d == -1.0 {
            assetOrientation = .down
        }
        return (assetOrientation, isPortrait)
    }
    
    func previewImage(from url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        var time = asset.duration
        time.value = min(time.value, 2)
        
        do {
            let imageRef = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            return UIImage(cgImage: imageRef)
        }
        catch let error as NSError
        {
            print("Error: previewImageFromVideo: \(error)")
            return nil
        }
    }
    
    var uniqueURL: URL? {
        let directory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .long
        let date = dateFormatter.string(from: Date())
        
        var pathComponent = "merge-\(date).mov"
        if directory.last != "/" {
            pathComponent = "/\(pathComponent)"
        }
        
        let path = directory.appending(pathComponent)
        return URL(fileURLWithPath: path)
    }
}

// MARK: - UIImagePickerControllerDelegate
extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        guard let imagePath = info[UIImagePickerControllerReferenceURL] as? URL else { return }
        addVideoURL(imagePath)
        imagePickerViewController.dismiss(animated: true, completion: nil)
        imagePickerViewController = nil
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        imagePickerViewController.dismiss(animated: true, completion: nil)
        imagePickerViewController = nil
    }
}

// MARK: - MPMediaPickerControllerDelegate
extension ViewController: MPMediaPickerControllerDelegate {
    func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
        let selectedSong = mediaItemCollection.items
        if selectedSong.count > 0 {
            let song = selectedSong[0]
            
            if let url = song.value(forProperty: MPMediaItemPropertyAssetURL) as? URL {
                musicAsset = AVAsset(url: url)
                musicLabel.text = song.value(forKeyPath: MPMediaItemPropertyTitle) as? String
            } else {
                musicLabel.text = "사용 불가"
            }
        }
        
        mediaPicker.dismiss(animated: true, completion: nil)
    }
    
    func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
        musicAsset = nil
        musicLabel.text = "불러오기 실패"
        mediaPicker.dismiss(animated: true, completion: nil)
    }
}

// MARK: - UITableViewDataSource
extension ViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return videoURLs.count
    }
}

// MARK: - UITableViewDelegate
extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "VideoClipCell") as! VideoTableViewCell
        
        cell.clipNameLabel.text = "비디오 클립 \(indexPath.row + 1)"
        cell.clipThumbnailImageView.image = previewImage(from: videoURLs[indexPath.row])
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        currentTableIndex = indexPath.row
    }
}
