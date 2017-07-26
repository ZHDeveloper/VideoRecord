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

public enum WriterCoordinatorStatus: Int {
    case unknown
    case writing
    case completed
    case failed
    case cancelled
    case paused
}

public class AssetWriterCoordinator: NSObject {
    
    public var status: WriterCoordinatorStatus {
        switch asswtWriter.status {
        case .unknown:
            return .unknown
        case .writing:
            if isPaused {
                return .paused
            }
            return .writing
        case .completed:
            return .completed
        case .failed:
            print(asswtWriter.error)
            return .failed
        case .cancelled:
            return .cancelled
        }
    }
    
    public var duration: CMTime {
        if lastTimestamp.value > 0 {
            if timeOffset.value > 0 {
                print(status)
                return CMTimeSubtract(CMTimeSubtract(lastTimestamp, startTime),timeOffset)
            }
            else {
                return CMTimeSubtract(lastTimestamp, startTime)
            }
        }
        else {
            return kCMTimeZero
        }
    }
    
    public static let defaultVideoSetting: [String : Any] = [ AVVideoCodecKey: AVVideoCodecH264, AVVideoWidthKey: UIScreen.main.bounds.size.width,AVVideoHeightKey: UIScreen.main.bounds.size.height]
    
    public static let defaultAudioSetting: [String: Any] = [ AVFormatIDKey: kAudioFormatMPEG4AAC, AVNumberOfChannelsKey: 1, AVSampleRateKey: 22050]
    
    private var asswtWriter: AVAssetWriter!
    private var videoWriterInput: AVAssetWriterInput!
    private var audioWriterInput: AVAssetWriterInput!
    
    private var startTime: CMTime = kCMTimeInvalid
    private var lastTimestamp: CMTime = kCMTimeInvalid
    private var timeOffset: CMTime = kCMTimeInvalid
    
    private var isPaused: Bool = false
    private var isDiscount: Bool = false
    
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
        guard status == .unknown else {
            return false
        }
        videoWriterInput.transform = transform
        timeOffset = kCMTimeZero
        return asswtWriter.startWriting()
    }
    
    public func pauseWriting() {
        guard status == .writing else { return }
        isPaused = true
        isDiscount = true
    }
    
    public func resumeWriting() {
        guard status == .paused else { return }
        isPaused = false
        print(status)
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
            self.startTime = kCMTimeInvalid
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
        
        var buffer = buffer
        
        guard status == .writing else { return }
        
        let presentTimeStamp = CMSampleBufferGetPresentationTimeStamp(buffer)
        
        self.startSessionIfNecessary(timestamp: presentTimeStamp)
        
        lastTimestamp = presentTimeStamp
        
        if isDiscount {
            if type == .video { return }
            
            isDiscount = false
            
            if timeOffset.value > 0 {
                let margin = CMTimeSubtract(presentTimeStamp, lastTimestamp)
                timeOffset = CMTimeAdd(timeOffset, margin)
            }
            else {
                timeOffset = CMTimeSubtract(presentTimeStamp, startTime)
            }
        }
        
        if timeOffset.value > 0 {
            buffer = ajustTimeStamp(sample: buffer, offset: timeOffset)
        }
        
        guard CMSampleBufferDataIsReady(buffer) else { return }
        
        switch type {
            case .video:
                if videoWriterInput.isReadyForMoreMediaData {
                    videoWriterInput.append(buffer)
                }
            default:
                if audioWriterInput.isReadyForMoreMediaData {
                    audioWriterInput.append(buffer)
                }
        }
    }
    
    
    private func startSessionIfNecessary(timestamp: CMTime) {
        if !self.startTime.isValid {
            self.startTime = timestamp
            asswtWriter.startSession(atSourceTime: timestamp)
        }
    }
    
    public func sampleBufferOffset(withSampleBuffer sampleBuffer: CMSampleBuffer, timeOffset: CMTime, duration: CMTime?) -> CMSampleBuffer? {
        var itemCount: CMItemCount = 0
        var status = CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, 0, nil, &itemCount)
        if status != 0 {
            return nil
        }
        
        var timingInfo = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(duration: CMTimeMake(0, 0), presentationTimeStamp: CMTimeMake(0, 0), decodeTimeStamp: CMTimeMake(0, 0)), count: itemCount)
        status = CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, itemCount, &timingInfo, &itemCount);
        if status != 0 {
            return nil
        }
        
        if let dur = duration {
            for i in 0 ..< itemCount {
                timingInfo[i].decodeTimeStamp = CMTimeSubtract(timingInfo[i].decodeTimeStamp, timeOffset);
                timingInfo[i].presentationTimeStamp = CMTimeSubtract(timingInfo[i].presentationTimeStamp, timeOffset);
                timingInfo[i].duration = dur
            }
        } else {
            for i in 0 ..< itemCount {
                timingInfo[i].decodeTimeStamp = CMTimeSubtract(timingInfo[i].decodeTimeStamp, timeOffset);
                timingInfo[i].presentationTimeStamp = CMTimeSubtract(timingInfo[i].presentationTimeStamp, timeOffset);
            }
        }
        
        var sampleBufferOffset: CMSampleBuffer? = nil
        CMSampleBufferCreateCopyWithNewTiming(kCFAllocatorDefault, sampleBuffer, itemCount, &timingInfo, &sampleBufferOffset)
        
        return sampleBufferOffset!
    }
    
    func ajustTimeStamp(sample: CMSampleBuffer, offset: CMTime) -> CMSampleBuffer {
        var count: CMItemCount = 0
        CMSampleBufferGetSampleTimingInfoArray(sample, 0, nil, &count);
        var info = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(duration: CMTimeMake(0, 0), presentationTimeStamp: CMTimeMake(0, 0), decodeTimeStamp: CMTimeMake(0, 0)), count: count)
        CMSampleBufferGetSampleTimingInfoArray(sample, count, &info, &count);
        
        for i in 0..<count {
            info[i].decodeTimeStamp = CMTimeSubtract(info[i].decodeTimeStamp, offset);
            info[i].presentationTimeStamp = CMTimeSubtract(info[i].presentationTimeStamp, offset);
        }
        
        var out: CMSampleBuffer?
        CMSampleBufferCreateCopyWithNewTiming(nil, sample, count, &info, &out);
        return out!
    }
}
