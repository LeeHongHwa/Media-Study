//
//  ViewController.swift
//  PenguinPet
//
//  Created by Michael Briscoe on 1/13/16.
//  Copyright © 2016 Razeware LLC. All rights reserved.
// 

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    @IBOutlet weak var penguinImageView: UIImageView!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    
    var audioStatus: AudioStatus = AudioStatus.Stopped
    
    var audioRecorder: AVAudioRecorder!
    var audioPlayer: AVAudioPlayer!
    
    // MARK: - Setup
    override func viewDidLoad() {
        super.viewDidLoad()
        setupRecorder()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    // MARK: - Controls
    @IBAction func didTapRecordButton(_ sender: UIButton) {
        if appHasMicAccess == true { // Look into why I did this ;]
            if audioStatus != .Playing {
                switch audioStatus {
                case .Stopped:
                    recordButton.setBackgroundImage(#imageLiteral(resourceName: "button-record1"), for: .normal)
                    record()
                case .Recording:
                    recordButton.setBackgroundImage(#imageLiteral(resourceName: "button-record"), for: .normal)
                    stopRecording()
                default:
                    break
                }
            }
        } else {
            recordButton.isEnabled = false
            let theAlert = UIAlertController(title: "Requires Microphone Access",
                                             message: "Go to Settings > PenguinPet > Allow PenguinPet to Access Microphone.\nSet switch to enable.",
                                             preferredStyle: .alert)
            
            theAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.view?.window?.rootViewController?.present(theAlert, animated: true, completion:nil)
        }
        
    }
    
    @IBAction func didTapPlayButton(_ sender: UIButton) {
        if audioStatus != .Recording {
            switch audioStatus {
            case .Stopped:
                play()
            case .Playing:
                stopPlayback()
            default:
                break
            }
        }
    }
}

// MARK: - AVFoundation Methods
extension ViewController: AVAudioPlayerDelegate, AVAudioRecorderDelegate {
    
    // MARK: Recording
    func setupRecorder() {
        let fileURL = memoURL
        let recordSetting = [AVFormatIDKey: Int(kAudioFormatLinearPCM),
                             AVSampleRateKey: 44100,
                             AVNumberOfChannelsKey: 1,
                             AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue]
        
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: recordSetting)
            audioRecorder.delegate = self
            audioRecorder.prepareToRecord()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func record() {
        audioStatus = .Recording
        audioRecorder.record()
    }
    
    func stopRecording() {
        recordButton.setBackgroundImage(#imageLiteral(resourceName: "button-record"), for: .normal)
        audioStatus = .Stopped
        audioRecorder.stop()
    }
    
    // MARK: Playback
    func play() {
        let fileURL = memoURL
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            audioPlayer.delegate = self
            guard audioPlayer.duration > 0 else { return }
            setPlayButtonOn(true)
            audioPlayer.play()
            audioStatus = .Playing
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func stopPlayback() {
        setPlayButtonOn(false)
        audioStatus = .Stopped
    }
    
    func setPlayButtonOn(_ flag: Bool) {
        if flag == true {
            playButton.setBackgroundImage(#imageLiteral(resourceName: "button-play1"), for: .normal)
        } else {
            playButton.setBackgroundImage(#imageLiteral(resourceName: "button-play"), for: .normal)
        }
    }
    
    // MARK: Delegates
    
    // MARK: Notifications
    
    // MARK: - Helpers
    
    var memoURL: URL {
        let tempDir = NSTemporaryDirectory()
        let filePath = tempDir + "/TempMemo.caf"
        
        return URL(fileURLWithPath: filePath)
    }
}


