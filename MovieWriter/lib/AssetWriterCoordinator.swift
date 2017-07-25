//
//  CaptuerSessionMovieWriter.swift
//  MovieWriter
//
//  Created by ZhiHua Shen on 2017/7/24.
//  Copyright © 2017年 ZhiHua Shen. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

public enum SampleBufferType {
    case video
    case audio
}

public class AssetWriterCoordinator: NSObject {
    
    public var status: AVAssetWriterStatus {
        return asswtWriter.status
    }
    
    public static let defaultVideoSetting: [String : Any] = [ AVVideoCodecKey: AVVideoCodecH264, AVVideoWidthKey: UIScreen.main.bounds.size.width,AVVideoHeightKey: UIScreen.main.bounds.size.height]
    
    public static let defaultAudioSetting: [String: Any] = [ AVFormatIDKey: kAudioFormatMPEG4AAC, AVNumberOfChannelsKey: 1, AVSampleRateKey: 22050]
    
    private var asswtWriter: AVAssetWriter!
    private var videoWriterInput: AVAssetWriterInput!
    private var audioWriterInput: AVAssetWriterInput!
    
    private var startTime: CMTime?
    
    private override init() { super.init() }

    public init(fileUrl: URL, videoSetting: [String : Any] = AssetWriterCoordinator.defaultVideoSetting, audioSetting: [String: Any] = AssetWriterCoordinator.defaultAudioSetting) throws {
        super.init()
        
        do {
            asswtWriter = try AVAssetWriter(outputURL: fileUrl, fileType: AVFileType.mp4)
            
            /// initial writer input
            videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSetting)
            videoWriterInput.expectsMediaDataInRealTime = true
            audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSetting)
            audioWriterInput.expectsMediaDataInRealTime = true
            
            guard asswtWriter.canAdd(videoWriterInput) else {
                let error = NSError(domain: "AVAssetWriterError", code: -1999, userInfo: [NSLocalizedFailureReasonErrorKey:"Can not add VideoWriterInput"])
                throw error
            }
            guard asswtWriter.canAdd(audioWriterInput) else {
                let error = NSError(domain: "AVAssetWriterError", code: -1999, userInfo: [NSLocalizedFailureReasonErrorKey: "Can not add AudioWriterInput"])
                throw error
            }
            asswtWriter.add(videoWriterInput)
            asswtWriter.add(audioWriterInput)
            
        } catch {
            throw error
        }
    }
    
    @discardableResult
    public func startWriting() -> Bool {
        return startWritingInOrientation(CGAffineTransform.identity)
    }
    
    @discardableResult
    public func startWritingInOrientation(_ transform: CGAffineTransform) -> Bool {
        guard asswtWriter.status == .unknown else {
            return false
        }
        videoWriterInput.transform = transform
        return asswtWriter.startWriting()
    }

    public func cancelWriting() {
        
        guard status == .writing else { return }

        videoWriterInput.markAsFinished()
        audioWriterInput.markAsFinished()

        return asswtWriter.cancelWriting()
    }
    
    public func finishWriting() {
        finishWritingWithCompletionHandler {}
    }
    
    /// handler will call back when status is writing
    public func finishWritingWithCompletionHandler(_ handler: @escaping ()->()) {
        
        guard status == .writing else { return }
        
        videoWriterInput.markAsFinished()
        audioWriterInput.markAsFinished()

        asswtWriter.finishWriting {
            self.startTime = nil
            DispatchQueue.main.async {
                handler()
            }
        }
    }
    
    public func saveToAlbumWithCompletionHandler(_ handler:((Bool,Error?) -> ())? = nil) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: self.asswtWriter.outputURL)
        }, completionHandler: handler)
    }
    
    public func processBuffer(_ buffer: CMSampleBuffer,type: SampleBufferType) {
        
        guard status == .writing else { return }
        
        if startTime == nil {
            startTime = CMSampleBufferGetPresentationTimeStamp(buffer)
            asswtWriter.startSession(atSourceTime: startTime!)
        }
        
        switch type {
            case .video:
                if videoWriterInput.isReadyForMoreMediaData {
                    videoWriterInput.append(buffer)
                }
            case .audio:
                if audioWriterInput.isReadyForMoreMediaData {
                    audioWriterInput.append(buffer)
                }
        }
    }
}
