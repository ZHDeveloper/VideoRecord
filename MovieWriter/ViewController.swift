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
    var url: URL!
    var timer: CADisplayLink!
    
    @IBOutlet weak var flashButton: UIButton!
    @IBOutlet weak var progressView: UIProgressView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        captureCoordinator = try! CaptureSessionCoordinator()
        
        view.insertSubview(captureCoordinator.previewView, at: 0)
        captureCoordinator.previewView.fillToSuperview()
        
        try? captureCoordinator.prepareSession()
        
        url = NSURL.fileURL(withPath: "\(NSTemporaryDirectory())tmp\(arc4random()).mp4")
        writerCoordinator = try! AssetWriterCoordinator(fileUrl: url)
        
        captureCoordinator.movieWriter = writerCoordinator
    }
    
    @IBAction func recordAction(_ sender: UIButton) {
        
        if writerCoordinator.status == .unknown {
            writerCoordinator.startWriting()
            timer = CADisplayLink(target: self, selector: #selector(updateProgress))
            timer.add(to: RunLoop.main, forMode: .commonModes)
        }
        else if writerCoordinator.status == .writing {
            timer.isPaused = true
            writerCoordinator.pauseWriting()
        }
        else if writerCoordinator.status == .paused {
            timer.isPaused = false
            writerCoordinator.resumeWriting()
        }
        
        sender.isSelected = !sender.isSelected
    }
    
    @IBAction func closeAction(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func swapAction(_ sender: Any) {
        
        try? captureCoordinator.swapCameras()
        if captureCoordinator.capmerPosition == .front {
            flashButton.isSelected = false
        }
    }
    
    @IBAction func flashAction(_ sender: UIButton) {
        let success = captureCoordinator.toggleFlash()
        if success {
            sender.isSelected = !sender.isSelected
        }
    }
    
    @objc func updateProgress() {
        let proportion = CMTimeGetSeconds(writerCoordinator.duration) / 15
        progressView.progress = Float(proportion)
        if proportion >= 1 {
            timer.invalidate()
            writerCoordinator.finishWritingWithCompletionHandler {
                let playerVC = MPMoviePlayerViewController(contentURL: self.url)!
                playerVC.moviePlayer.prepareToPlay()
                playerVC.moviePlayer.play()
                self.present(playerVC, animated: true, completion: nil)
            }
        }
    }
    
}
