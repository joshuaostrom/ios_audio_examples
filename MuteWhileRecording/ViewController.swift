//
//  ViewController.swift
//  MuteWhileRecording
//
//  Created by JOSHUA OSTROM on 12/8/19.
//  Copyright © 2019 JOSHUA OSTROM. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation

class ViewController: UIViewController, AVAudioRecorderDelegate {

    var startButton, stopButton, playRecordedButton : UIButton!
    var videoPlayer: AVPlayer!
    var audioPlayer: AVAudioPlayer?

    
    var recordingSession: AVAudioSession!
    var audioRecorder: AVAudioRecorder!
   
    var initialVolumeLevel: Float!
    var speakerWasOn: Bool!
    var userAllowed: Bool = false
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // If we wanted to Fade one could look at a
        //
        //    try! AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback,
        //                              options: //AVAudioSession.CategoryOptions.mixWithOthers)
        //
        // here and then a setVolume(0, fadeDuration: 3) OR equiv fade
        prepAudioSession()
        setupButtons()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        setupVideo()
    }
    
    func setupVideo(){
        let videoURL = URL(string: "https://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4")
        videoPlayer = AVPlayer(url: videoURL!)
        let playerLayer = AVPlayerLayer(player: videoPlayer)
        playerLayer.frame = self.view.bounds
        self.view.layer.addSublayer(playerLayer)
        videoPlayer.play()
    }
    
    func setupButtons(){
        startButton = UIButton(frame: CGRect(x: 0,y: 0,width: 60,height: 50))
        startButton.backgroundColor = UIColor.green
        startButton.layer.masksToBounds = true
        startButton.setTitle("start", for: UIControl.State())
        startButton.layer.cornerRadius = 20.0
        startButton.layer.position = CGPoint(x: view.bounds.width/5, y:view.bounds.height-50)
        startButton.addTarget(self, action: #selector(ViewController.onClickStartButton(_:)), for: .touchUpInside)
      
        stopButton = UIButton(frame: CGRect(x: 0,y: 0,width: 60,height: 50))
        stopButton.backgroundColor = UIColor.red
        stopButton.layer.masksToBounds = true
        stopButton.setTitle("stop", for: UIControl.State())
        stopButton.layer.cornerRadius = 20.0
        stopButton.layer.position = CGPoint(x: view.bounds.width/5 * 2, y:view.bounds.height-50)
        stopButton.addTarget(self, action: #selector(ViewController.onClickStopButton(_:)), for: .touchUpInside)
        
        playRecordedButton = UIButton(frame: CGRect(x: 0,y: 0,width: 150,height: 50))
        playRecordedButton.backgroundColor = UIColor.blue
        playRecordedButton.layer.masksToBounds = true
        playRecordedButton.setTitle("play recorded", for: UIControl.State())
        playRecordedButton.layer.cornerRadius = 20.0
        playRecordedButton.layer.position = CGPoint(x: view.bounds.width/5 * 3.5, y:view.bounds.height-50)
        playRecordedButton.addTarget(self, action: #selector(ViewController.onClickPlayButton(_:)), for: .touchUpInside)
        
        view.addSubview(startButton)
        view.addSubview(stopButton);
        view.addSubview(playRecordedButton);
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    

    func finishRecording(success: Bool) {
        audioRecorder.stop()
        audioRecorder = nil
    }
 
    func audioFileName() -> URL {
        return getDocumentsDirectory().appendingPathComponent("correction.m4a")
    }

    func prepAudioSession(){
        recordingSession = AVAudioSession.sharedInstance()
        
        do {
            // Note the .playAndRecord required as we want the video audio to continue
            // playing while we record audio
            // The mode: .voiceChat enables the tonal optimization and will minimize the
            // audio coming from the other channels
            // This is the out-of-the-box mode, for finer grained control we can look at
            // Remote IO / Audio Units that IOs provides
            
            try recordingSession.setCategory(.playAndRecord, mode: .voiceChat, options: AVAudioSession.CategoryOptions.defaultToSpeaker)
            
            // On the radar but not needed:
            // options: AVAudioSession.CategoryOptions.mixWithOthers
            // options: AVAudioSession.CategoryOptions.duckOthers
            
            
            try recordingSession.setActive(true)
            recordingSession.requestRecordPermission() { [unowned self] allowed in
                DispatchQueue.main.async {
                    self.userAllowed = allowed
                }
            }
        } catch {
            // failed to record!
        }
     }

    func startRecording() {
        DispatchQueue.main.async {
            let audioFilename = self.audioFileName()
            
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            do {
                self.audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
                self.audioRecorder.delegate = self
                self.audioRecorder.record()
                
            } catch {
                self.finishRecording(success: false)
            }
        }
    }
    
    
    
    func stopRecordingAudio(){
        finishRecording(success: true)
    }
    
    @objc func onClickStartButton(_ sender: UIButton){
        // Dead code now, after discussing further we do want audio
        // to contine playing
        //turnOffVideoVolume()
        startRecording()
        startButton.isEnabled = false
        stopButton.isEnabled = true
    }
    
    @objc func onClickStopButton(_ sender: UIButton){
        stopRecordingAudio()
        // No longer needed after discussing further
        //restoreVideoVolume()
        startButton.isEnabled = true
        stopButton.isEnabled = false
    }
 
    @objc func onClickPlayButton(_ sender: UIButton){
        videoPlayer.pause()
        let audioFilename = self.audioFileName()
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioFilename)
            audioPlayer?.play()
        } catch {
            // couldn't load file :(
        }
    }
    
    func turnOffVideoVolume(){
        speakerWasOn = usingSpeaker()
        initialVolumeLevel = videoPlayer.volume
        // Turn off video volume so we can record the audio
        //videoPlayer.volume = 0.0
    }
    
    func restoreVideoVolume(){
        if(speakerWasOn && !usingSpeaker()){
            // Recording will axe audio flowing to the speaker, restore it if needed
            try! AVAudioSession.sharedInstance().overrideOutputAudioPort(AVAudioSession.PortOverride.speaker)
        }
    }
    
    func usingSpeaker() -> Bool {
        let currentRoute = AVAudioSession.sharedInstance().currentRoute
        
        for description in currentRoute.outputs {
            if description.portType == AVAudioSession.Port.builtInSpeaker{
                return true
            }
        }
        return false
    }
    
    // If we wanted to Fade one could look at a
    //
    //    try! AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback,
    //                              options: //AVAudioSession.CategoryOptions.mixWithOthers)
    //
    // here and then a setVolume(0, fadeDuration: 3) OR equiv fade
    
    
    
    
    
 /*
    // Not currently using but a best practice to watch for audio route changes
    // https://developer.apple.com/documentation/avfoundation/avaudiosession/responding_to_audio_session_route_changes
    func registerForNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleInterruption),
                                               name: AVAudioSession.interruptionNotification,
                                               object: AVAudioSession.sharedInstance())
    }
    
    @objc
    func handleInterruption(_ notification: Notification) {
        
        guard let info = notification.userInfo,
            let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                return
        }
        if type == .began {
            print("Interruption began, take appropriate actions (save state, update user interface)")
        }
        else if type == .ended {
            guard let optionsValue =
                info[AVAudioSessionInterruptionOptionKey] as? UInt else {
                    return
            }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                print("Interruption Ended - playback should resume")
            }
        }
        
    }
 */

}

