//
//  ViewController.swift
//  MovieWriter
//
//  Created by ZhiHua Shen on 2017/7/24.
//  Copyright © 2017年 ZhiHua Shen. All rights reserved.
//

import UIKit
import MediaPlayer
import AVKit

class ViewController: UIViewController {
    
    var captureCoordinator: CaptureSessionCoordinator!
    var writerCoordinator: AssetWriterCoordinator!
    var url: URL?
    
    var playerVC: MPMoviePlayerViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        captureCoordinator = try! CaptureSessionCoordinator()
        
        view.insertSubview(captureCoordinator.previewView, at: 0)
        captureCoordinator.previewView.fillToSuperview()
        
        try? captureCoordinator.prepareSession()
        
        url = NSURL.fileURL(withPath: "\(NSTemporaryDirectory())tmp\(arc4random()).mp4")
        writerCoordinator = try! AssetWriterCoordinator(fileUrl: url!)
        
        captureCoordinator.movieWriter = writerCoordinator
    }
    
    
    @IBAction func recordAction(_ sender: Any) {
        
    }
    
    @IBAction func closeAction(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func swapAction(_ sender: Any) {
        try? captureCoordinator.swapCameras()
    }
    
    @IBAction func flashAction(_ sender: UIButton) {
        let success = (try? captureCoordinator.toggleFlash()) ?? false
        if success {
            sender.isSelected = !sender.isSelected
        }
    }
    
    @IBAction func playAction(_ sender: Any) {
        
        playerVC = MPMoviePlayerViewController(contentURL: url!)
        
        playerVC?.moviePlayer.prepareToPlay()
        playerVC?.moviePlayer.play()
        
        present(playerVC!, animated: true, completion: nil)
        
        let player = AVPlayerViewController()
        
    }
    
}

