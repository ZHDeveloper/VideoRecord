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
            return .failed
        case .cancelled:
            return .cancelled
        }
    }
    
    public var duration: Double {
        let duration = CMTimeGetSeconds(CMTimeSubtract(lastAudioPts, startTime))
        return duration.isNaN ? 0.0 : duration
    }
    
    public static let defaultVideoSetting: [String : Any] = [ AVVideoCodecKey: AVVideoCodecH264, AVVideoWidthKey: UIScreen.main.bounds.size.width,AVVideoHeightKey: UIScreen.main.bounds.size.height]
    
    public static let defaultAudioSetting: [String: Any] = [ AVFormatIDKey: kAudioFormatMPEG4AAC, AVNumberOfChannelsKey: 1, AVSampleRateKey: 22050]
    
    private var asswtWriter: AVAssetWriter!
    private var videoWriterInput: AVAssetWriterInput!
    private var audioWriterInput: AVAssetWriterInput!
    
    private var isPaused: Bool = false
    private var isDiscount: Bool = false
    
    private var startTime: CMTime = kCMTimeInvalid
    private var timeOffset: CMTime = kCMTimeInvalid
    private var lastAudioPts: CMTime = kCMTimeInvalid
    
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
    
    public func processBuffer(_ sampleBuffer: CMSampleBuffer,type: SampleBufferType) {
        
        guard status == .writing else { return }
        
        var pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        self.startSessionIfNecessary(timestamp: pts)
        
        if isDiscount {
            if type == .video { return }
            
            isDiscount = false
            
            let isAudioPtsValid = lastAudioPts.flags.intersection(CMTimeFlags.valid)
            
            if isAudioPtsValid.rawValue != 0 {

                let isTimeOffsetPtsValid = timeOffset.flags.intersection(CMTimeFlags.valid)
                if isTimeOffsetPtsValid.rawValue != 0 {
                    pts = CMTimeSubtract(pts, timeOffset);
                }
                let offset = CMTimeSubtract(pts, lastAudioPts);
                
                if (timeOffset.value == 0)
                {
                    timeOffset = offset;
                }
                else
                {
                    timeOffset = CMTimeAdd(timeOffset, offset);
                }
            }
            lastAudioPts.flags = CMTimeFlags()
        }
        
        var buffer = sampleBuffer

        if timeOffset.value > 0 {
            buffer = ajustTimeStamp(sample: sampleBuffer, offset: timeOffset)
        }

        if type == .audio {
            var pts = CMSampleBufferGetPresentationTimeStamp(buffer)
            let dur = CMSampleBufferGetDuration(buffer)
            if (dur.value > 0)
            {
                pts = CMTimeAdd(pts, dur)
            }
            self.lastAudioPts = pts
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
        if !startTime.isValid {
            startTime = timestamp
            asswtWriter.startSession(atSourceTime: timestamp)
        }
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
    
    deinit {
        print("AssetWriterCoordinator has deinit!!!")
    }
}
