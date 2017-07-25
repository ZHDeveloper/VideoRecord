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
    case addVideoDeviceInputFail
    case addAudioDeviceInputFail
    case addVideoOutputFail
    case addAudioOutputFail
    
    public var errorDescription: String? {
        switch self {
        case .cameraAuthorDenied:
            return "Camera use not allow!!!"
        case .addVideoDeviceInputFail:
            return "Can not add input video device!!!"
        case .addAudioDeviceInputFail:
            return "Can not add input audio device!!!"
        case .addVideoOutputFail:
            return "Can not add video data output!!!"
        case .addAudioOutputFail:
            return "Can not add audio data output!!!"
        }
    }
}

public class CaptureSessionCoordinator: NSObject {
    
    public let previewView = CaptureSessionPreviewView(frame: .zero)
    
    public let session = AVCaptureSession()
    
    public var captureQueue: DispatchQueue = DispatchQueue(label: "CaptureSessionCoordinator")
    
    public var movieWriter: AssetWriterCoordinator?
    
    private var videoDeviceInput: AVCaptureDeviceInput?
    
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
    
    init(sessionPreset preset: AVCaptureSession.Preset = .vga640x480, cameraPosition position: AVCaptureDevice.Position = .back) throws {
        super.init()
        session.sessionPreset = preset
        guard let videoDevice = self.cameraDevice(with: position) else {
            let error = NSError(domain: "Error", code: -1999, userInfo: [NSLocalizedDescriptionKey:"Can not init video device with \(position)"])
            throw error
        }
        videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice)
    }
}

public extension CaptureSessionCoordinator {
    
    func prepareSession() throws {
        
        if session.isRunning { return }
        
        guard AVCaptureDevice.authorizationStatus(for: .video) != .denied else {
            throw CoordinatorError.cameraAuthorDenied
        }
        guard let videoDeviceInput = videoDeviceInput, session.canAddInput(videoDeviceInput) else {
            throw CoordinatorError.addVideoDeviceInputFail
        }
        guard let audioDeviceInput = audioDeviceInput, session.canAddInput(audioDeviceInput) else {
            throw CoordinatorError.addAudioDeviceInputFail
        }
        guard session.canAddOutput(videoOutput) else {
            throw CoordinatorError.addVideoOutputFail
        }
        guard session.canAddOutput(audioOutput) else {
            throw CoordinatorError.addAudioOutputFail
        }
        
        session.addInput(videoDeviceInput)
        session.addInput(audioDeviceInput)
        
        session.addOutput(videoOutput)
        session.addOutput(audioOutput)
        
        /// 视频录制的方向
        videoConnection?.videoOrientation = .portrait
        
        videoOutput.setSampleBufferDelegate(self, queue: captureQueue)
        audioOutput.setSampleBufferDelegate(self, queue: captureQueue)
        
        previewView.session = session
        
        session.startRunning()
    }
    
    public func toggleFlash() throws -> Bool {
        
        if !session.isRunning { return false }
        
        guard let device = videoDeviceInput?.device else { return false }
        
        do {
            try device.lockForConfiguration()
        } catch  {
            throw error
        }
        if device.flashMode == .on {
            if device.isFlashModeSupported(.off),device.isTorchModeSupported(.off) {
                device.flashMode = .off
                device.torchMode = .off
            }
        }
        else if device.flashMode == .off {
            if device.isFlashModeSupported(.on),device.isTorchModeSupported(.on) {
                device.flashMode = .on
                device.torchMode = .on
            }
        }
        device.unlockForConfiguration()
        return true
    }
    
    public func swapCameras() throws {
        
        if !session.isRunning { return }
        guard let device = videoDeviceInput?.device else { return }
        
        var newDevice: AVCaptureDevice? = nil
        
        if device.position == .back {
            newDevice = cameraDevice(with: .front)
        }
        else if device.position == .front {
            newDevice = cameraDevice(with: .back)
        }
        
        guard let aDevice = newDevice else { return }
        
        do {
            let newDeviceInput = try AVCaptureDeviceInput.init(device: aDevice)
            session.beginConfiguration()
            session.removeInput(videoDeviceInput!)
            session.addInput(newDeviceInput)
            session.commitConfiguration()
            videoDeviceInput = newDeviceInput
        } catch {
            throw error
        }
    }
    
    fileprivate func cameraDevice(with position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let devices = AVCaptureDevice.devices(for: AVMediaType.video)
        for aDevice in devices {
            if aDevice.position == position { return aDevice}
        }
        return nil
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


