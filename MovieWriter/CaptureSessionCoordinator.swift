//
//  CaptureSessionCoordinator.swift
//  MovieWriter
//
//  Created by ZhiHua Shen on 2017/7/24.
//  Copyright © 2017年 ZhiHua Shen. All rights reserved.
//

import UIKit
import AVFoundation

public enum CoordinatorError: Error,LocalizedError {
    case cameraAuthorDenied
    case addDeviceInputFail
    case addDataOutputFail
    
    public var errorDescription: String? {
        switch self {
        case .cameraAuthorDenied:
            return "Camera use not allow!!!"
        case .addDeviceInputFail:
            return "Can not add input device!!!"
        case .addDataOutputFail:
            return "Can not add video data output!!!"
        }
    }
}

public class CaptureSessionCoordinator: NSObject {
    
    public let previewView = CaptureSessionPreviewView(frame: .zero)
    
    public let session = AVCaptureSession()
    
    public var captureQueue: DispatchQueue = DispatchQueue(label: "CaptureSessionCoordinator")
    
    private var movieWriter: AssetWriterCoordinator?
    
    private let videoDeviceInput: AVCaptureDeviceInput? = {
        guard let device = AVCaptureDevice.default(for: .video) else { return nil}
        let input = try? AVCaptureDeviceInput(device: device)
        return input
    }()
    
    private let audioDeviceInput: AVCaptureDeviceInput? = {
        guard let device = AVCaptureDevice.default(for: .audio) else { return nil}
        let input = try? AVCaptureDeviceInput(device: device)
        return input
    }()
    
    private let videoOutput: AVCaptureVideoDataOutput = AVCaptureVideoDataOutput()
    private let audioOutput: AVCaptureAudioDataOutput = AVCaptureAudioDataOutput()
    
    lazy var audioConnection: AVCaptureConnection? = {
        let connection = audioOutput.connection(with: .audio)
        return connection
    }()
    
    lazy var videoConnection: AVCaptureConnection? = {
        let connection = videoOutput.connection(with: .video)
        return connection
    }()
    
    private override init() { super.init() }
    
    init(sessionPreset preset: AVCaptureSession.Preset = .vga640x480) {
        session.sessionPreset = preset
        super.init()
    }
}

public extension CaptureSessionCoordinator {
    
    func prepareSession() throws {
        
        if session.isRunning { return }
        
        guard AVCaptureDevice.authorizationStatus(for: .video) != .denied else {
            throw CoordinatorError.cameraAuthorDenied
        }
        
        guard let videoDeviceInput = videoDeviceInput, session.canAddInput(videoDeviceInput) else {
            throw CoordinatorError.addDeviceInputFail
        }

        session.addInput(videoDeviceInput)
        
        session.addInput(audioDeviceInput!)
        
        session.addOutput(videoOutput)
        session.addOutput(audioOutput)
        
        videoOutput.setSampleBufferDelegate(self, queue: captureQueue)
        audioOutput.setSampleBufferDelegate(self, queue: captureQueue)
        
        /// 视频录制的方向
        videoConnection?.videoOrientation = .portrait

        previewView.session = session
        
        session.startRunning()
    }
    
    func addTarget(_ writer: AssetWriterCoordinator) {
        movieWriter = writer
    }

}

extension CaptureSessionCoordinator: AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate {
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let movieWriter = movieWriter, movieWriter.status == .writing else { return }
        
        objc_sync_enter(self)
        
        if connection == audioConnection {
            movieWriter.processBuffer(sampleBuffer, type: .audio)
        }
        else if connection == videoConnection {
            movieWriter.processBuffer(sampleBuffer, type: .video)
        }
        
        objc_sync_exit(self)
    }
    
}

public class CaptureSessionPreviewView: UIView {
    
    public var session: AVCaptureSession? {
        get {
            return previewLayer.session
        }
        set {
            previewLayer.session = newValue
        }
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        previewLayer.videoGravity = .resizeAspectFill
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override class var layerClass: Swift.AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    public var previewLayer: AVCaptureVideoPreviewLayer {
        get {
            return layer as! AVCaptureVideoPreviewLayer
        }
    }
}


