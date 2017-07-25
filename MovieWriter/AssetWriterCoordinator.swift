//
//  CaptuerSessionMovieWriter.swift
//  MovieWriter
//
//  Created by ZhiHua Shen on 2017/7/24.
//  Copyright © 2017年 ZhiHua Shen. All rights reserved.
//

import UIKit
import AVFoundation

public enum BufferType {
    case video
    case audio
}

let screenW = UIScreen.main.bounds.size.width
let screenH = UIScreen.main.bounds.size.height

public class AssetWriterCoordinator: NSObject {
    
    public var status: AVAssetWriterStatus {
        return asswtWriter.status
    }
    
    private var asswtWriter: AVAssetWriter!
    private var videoWriterInput: AVAssetWriterInput!
    private var audioWriterInput: AVAssetWriterInput!
    
    private var startTime: CMTime?

    let videoSetting: [String : Any] = [
        AVVideoCodecKey: AVVideoCodecH264,
        AVVideoWidthKey: screenW,
        AVVideoHeightKey: screenH,
        AVVideoCompressionPropertiesKey: [
            AVVideoPixelAspectRatioKey: [
                AVVideoPixelAspectRatioHorizontalSpacingKey: 1,
                AVVideoPixelAspectRatioVerticalSpacingKey: 1
            ],
            AVVideoMaxKeyFrameIntervalKey: 1,
            AVVideoAverageBitRateKey: 1280000
        ]
    ]
    
    let audioSetting: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVNumberOfChannelsKey: 1,
        AVSampleRateKey: 22050
    ]
    
    private override init() { super.init() }

    public init(fileUrl: URL) throws {
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
                let error = NSError(domain: "AVAssetWriterError", code: -1999, userInfo: [NSLocalizedFailureReasonErrorKey:"Can not add AudioWriterInput"])
                throw error
            }
            asswtWriter.add(videoWriterInput)
            asswtWriter.add(audioWriterInput)
            
        } catch {
            throw error
        }
    }
    
    public func startWriting() {
        guard asswtWriter.status != .writing else {
            return
        }
        asswtWriter.startWriting()
    }
    
    public func startWritingInOrientation(_ transform: CGAffineTransform) {
        videoWriterInput.transform = transform
        startWriting()
    }

    public func cancelWriting() {
        if asswtWriter.status == .writing {
            videoWriterInput.markAsFinished()
            audioWriterInput.markAsFinished()
        }
        asswtWriter.cancelWriting()
    }
    
    public func finishWriting() {
        finishWritingWithCompletionHandler {}
    }
    
    public func finishWritingWithCompletionHandler(_ handler: @escaping ()->()) {
        if asswtWriter.status == .writing {
            videoWriterInput.markAsFinished()
            audioWriterInput.markAsFinished()
        }
        asswtWriter.finishWriting {
            handler()
            self.startTime = nil
        }
    }
    
    public func processBuffer(_ buffer: CMSampleBuffer,type: BufferType) {
        
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
