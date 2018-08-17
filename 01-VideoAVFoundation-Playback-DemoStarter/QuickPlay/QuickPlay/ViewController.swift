//
//  ViewController.swift
//  QuickPlay
//
//  Created by Michael Briscoe on 1/5/16.
//  Copyright © 2016 Razeware LLC. All rights reserved.
//

import Photos
import AVKit
import UIKit
import AVFoundation

class ViewController: UIViewController {
    @IBOutlet weak var videoTableView: UITableView!
    var imagePickerViewController: UIImagePickerController!
    
    var videoURLs = [URL]()
    var currentTableIndex = -1
    
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
                guard status == .authorized, let weakSelf = self else { return }
                weakSelf.presentImagePickerViewController()
            }
            
        case .authorized:
            presentImagePickerViewController()
            
        case .denied, .restricted:
            return
        }
    }
    
    private func presentImagePickerViewController() {
        imagePickerViewController = UIImagePickerController()
        imagePickerViewController.delegate = self
        imagePickerViewController.sourceType = .photoLibrary
        imagePickerViewController.allowsEditing = false
        imagePickerViewController.mediaTypes = ["public.movie"]
        
        present(imagePickerViewController, animated: true, completion: nil)
    }
    
    @IBAction func didTapaddRemoteStreamButton(_ sender: UIButton) {
        let alertController = UIAlertController(title: "Add Remote Stream", message: "Enter URL for remote stream.", preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
        alertController.addAction(UIAlertAction(title: "Done", style: .default, handler: { action in
            let theTextField = alertController.textFields![0] as UITextField
            self.addVideoURL(URL(string: theTextField.text!)!)
        }))
        
        alertController.addTextField { textField in
            textField.text = "https://youtu.be/QFoLamS9ODY"
        }
        
        present(alertController, animated: true, completion:nil)
    }
    
    func addVideoURL(_ url: URL) {
        videoURLs.append(url)
        videoTableView.reloadData()
    }
    
    @IBAction func didTapDeleteVideoClipButton(_ sender: UIButton) {
        if currentTableIndex != -1 {
            let alertController = UIAlertController(title: "Remove Clip", message: "Are you sure you want to remove this video clip from playlist?", preferredStyle: .alert)
            
            alertController.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
            alertController.addAction(UIAlertAction(title: "Yes", style: .destructive, handler: { action in
                self.videoURLs.remove(at: self.currentTableIndex)
                self.videoTableView.reloadData()
                self.currentTableIndex = -1
            }))
            
            present(alertController, animated: true, completion:nil)
            
        }
    }
    
    @IBAction func didTapPlayVideoClipButton(_ sender: UIButton) {
        guard currentTableIndex != 1 else { return }
        let player = AVPlayer(url: videoURLs[currentTableIndex])
        player.allowsExternalPlayback = false
        
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        
        present(playerViewController, animated: true) {
            playerViewController.player?.play()
        }
    }
    
    @IBAction func didTapPlayAllVideoClipsButton(_ sender: UIButton) {
        let playerItems = videoURLs.map { url -> AVPlayerItem in
            return AVPlayerItem(url: url)
        }
        guard !playerItems.isEmpty else { return }
        
        let queuePlayer = AVQueuePlayer(items: playerItems)
        queuePlayer.allowsExternalPlayback = false
        let playerViewController = AVPlayerViewController()
        playerViewController.player = queuePlayer
        
        present(playerViewController, animated: true) {
            playerViewController.player?.play()
        }
    }
    
    // MARK: - Helpers
    func previewImageFromVideo(url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        var time = asset.duration
        time.value = min(time.value, 2)
        
        do {
            let imageRef = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            return UIImage(cgImage: imageRef)
        } catch {
            print("[preview error] :\(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - UIImagePickerControllerDelegate
extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        let theImagePath: URL = info["UIImagePickerControllerReferenceURL"] as! URL
        addVideoURL(theImagePath)
        
        imagePickerViewController.dismiss(animated: true, completion: nil)
        imagePickerViewController = nil
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        imagePickerViewController.dismiss(animated: true, completion: nil)
        imagePickerViewController = nil
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
        
        cell.clipName.text = "Video Clip \(indexPath.row + 1)"
        
        if let previewImage = previewImageFromVideo(url: videoURLs[indexPath.row]) {
            cell.clipThumbnail.image = previewImage
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        currentTableIndex = indexPath.row
    }
}

