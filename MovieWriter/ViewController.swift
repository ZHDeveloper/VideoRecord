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
        
        captureCoordinator = CaptureSessionCoordinator()
        
        view.insertSubview(captureCoordinator.previewView, at: 0)
        captureCoordinator.previewView.fillToSuperview()
        
        try? captureCoordinator.prepareSession()
        
        url = NSURL.fileURL(withPath: "\(NSTemporaryDirectory())tmp\(arc4random()).mp4")
        writerCoordinator = try! AssetWriterCoordinator(fileUrl: url!)
        
        captureCoordinator.addTarget(writerCoordinator)
    }
    
    @IBAction func startRecordAction(_ sender: Any) {
        writerCoordinator.startWriting()
    }
    
    @IBAction func endRecordAction(_ sender: Any) {
        writerCoordinator.finishWritingWithCompletionHandler {
            print("---")
        }
    }
    
    @IBAction func playAction(_ sender: Any) {
        
        playerVC = MPMoviePlayerViewController(contentURL: url!)
        
        playerVC?.moviePlayer.prepareToPlay()
        playerVC?.moviePlayer.play()
        
        present(playerVC!, animated: true, completion: nil)
        
        let player = AVPlayerViewController()
        
    }
    
    @IBAction func cancelAction(_ sender: Any) {
        writerCoordinator.cancelWriting()
    }
    
}

