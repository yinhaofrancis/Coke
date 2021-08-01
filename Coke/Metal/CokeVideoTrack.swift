//
//  CokeVideoTrack.swift
//  CokeVideo_Example
//
//  Created by hao yin on 2021/2/17.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import Foundation
import AVFoundation
import CoreImage
extension CMSampleBuffer{
    public var currentTime:CMTime{
        if #available(iOS 13.0, *) {
            return self.presentationTimeStamp
        } else {
            return CMSampleBufferGetPresentationTimeStamp(self)
        }
    }
}

public class CokeAssetVideoTrack{
    
    public var videoFrameRate:Int = 30
    public var videoBitRate:Double = 16 * 1024 * 1024
    public var audioSampleRate:Double = 44100
    public var audioBitRate:Double = 64000
    public var numberOfChannel:Int = 2
//    public var quality:Double = 0.0
    private var group = DispatchGroup()
    private var queue = DispatchQueue(label: "CokeAssetVideoTrack")
    
    public func nextSampleBuffer() -> CVPixelBuffer? {
        self.nextSampleBuffer(curr: nil)
    }
    
    
    public var transform: CGAffineTransform{
        self.videoOutput.track.preferredTransform
    }
    
    public var audioMix: AVAudioMix?{
        return self.audioOutput.audioMix
    }
    
    public func ready() {
        self.reader.startReading()
    }
    
    
    public func finish() {
        self.reader.cancelReading()
        self.writer?.cancelWriting()
    }
    
    
    var last:CMSampleBuffer?
    var next:CMSampleBuffer?
    var minLen:CMTime{
        let len = CMTime(seconds: 10, preferredTimescale: .max)
        if len < self.during{
            return len
        }else{
            return self.during
        }
    }
    var currentRange:CMTimeRange
    var reader:AVAssetReader
    var writer:AVAssetWriter?
    public var filter:CokeMetalFilter?
    
    private func nextSampleBuffer(curr: CMTime? = nil) -> CVPixelBuffer? {
        if let current = curr{
            if(current > self.during || current < .zero){
                return nil
            }
            let time:CMTime = current - self.startTime
            if self.last == nil{
                self.last = self.videoOutput.copyNextSampleBuffer()
            }
            
            if self.next == nil{
                self.next = self.videoOutput.copyNextSampleBuffer()
            }
            if let l = self.last , let n = self.next {
                if l.currentTime <= time && n.currentTime > time{
                    return CMSampleBufferGetImageBuffer(l)
                }else{
                    self.last = n
                    self.next = self.videoOutput.copyNextSampleBuffer()
                    return self.nextSampleBuffer(curr: current)
                }
            }else {
                return nil
            }
        }else{
            guard let samp = self.videoOutput.copyNextSampleBuffer() else { return nil }
            return CMSampleBufferGetImageBuffer(samp)
        }
        
    }
    
    public var during: CMTime{
        self.videoOutput.track.asset?.duration ?? .zero
    }
    
    public let videoOutput:AVAssetReaderTrackOutput
    
    public let audioOutput:AVAssetReaderAudioMixOutput
    
    public var size: CGSize{
        return self.videoOutput.track.naturalSize
    }
    
    public init(asset:AVAsset) throws {
        self.reader = try AVAssetReader(asset: asset)
        
        guard let track = asset.tracks(withMediaType: .video).first else { throw NSError(domain: "no video", code: 0, userInfo: nil)}
        let videoSetting:[String:Any] = [
            kCVPixelBufferPixelFormatTypeKey as String:CokeConfig.videoColorFormat
        ]
        self.videoOutput = AVAssetReaderTrackOutput(track: track, outputSettings: videoSetting)

        self.reader.add(self.videoOutput)
        
        let atrack = asset.tracks(withMediaType: .audio)
        
        
        let audioSetting:[String:Any] = [AVFormatIDKey:kAudioFormatLinearPCM]

        self.audioOutput = AVAssetReaderAudioMixOutput(audioTracks: atrack, audioSettings: audioSetting)
       
        self.currentRange = CMTimeRange(start: .zero, duration: .zero)
        self.reader.add(audioOutput)
    }
    
    public func export(w:UInt,h:UInt,callback:@escaping (URL?,AVAssetWriter.Status)->Void) throws{
        
        let url = try CokeAssetVideoTrack.fileCreate(name: "a", ext: "mp4")
        self.ready()
        if(FileManager.default.fileExists(atPath: url.path)){
            try! FileManager.default.removeItem(at: url)
        }
        
        self.writer = try AVAssetWriter(url: url, fileType: .mp4)
        let compress:[String:Any] = [
            AVVideoAverageBitRateKey:self.videoBitRate,
            AVVideoExpectedSourceFrameRateKey:self.videoFrameRate,
        ]
        
        var vset:[String:Any] = [
            AVVideoWidthKey:w,
            AVVideoHeightKey:h,
            AVVideoCompressionPropertiesKey:compress,
        ]
        if #available(iOS 11.0, *) {
            
            vset[AVVideoCodecKey] = AVVideoCodecType.h264
        } else {
            vset[AVVideoCodecKey] = AVVideoCodecH264
            // Fallback on earlier versions
        }
        guard let videoTracks = loadAsset(type: .video, setting: vset)  else { throw NSError(domain: "video config fail", code: 0, userInfo: nil)}
        videoTracks.transform = self.videoOutput.track.preferredTransform;
        let videoTracksAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoTracks, sourcePixelBufferAttributes: nil)
        
        let dic = [
            AVFormatIDKey : kAudioFormatMPEG4AAC,
            AVEncoderBitRateKey:self.audioBitRate,
            AVSampleRateKey:self.audioSampleRate,
            AVNumberOfChannelsKey:self.numberOfChannel
        ] as [String : Any]
        
        let audioTracks = loadAsset(type: .audio, setting: dic)
        self.writer?.startWriting()
        self.writer?.startSession(atSourceTime: .zero)
        self.group.enter()
        var videoEnd = false
        var audioEnd = false
        videoTracks.requestMediaDataWhenReady(on: self.queue) {
            while (!videoEnd && videoTracks.isReadyForMoreMediaData){
                if let sampleBuffer = self.videoOutput.copyNextSampleBuffer(){
                    if let pixelbff = CMSampleBufferGetImageBuffer(sampleBuffer){
                        if let pf = self.filter{
                            if let p = pf.filter(pixel: pixelbff){
                                videoTracksAdaptor.append(p, withPresentationTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
                                continue
                            }
                        }else{
                            videoTracks.append(sampleBuffer)
                            continue
                        }
                    }
                    
                }else{
                    videoEnd = true
                    break
                }
            }
            if videoEnd{
                videoTracks.markAsFinished()
                self.group.leave()
            }
        };
        self.group.enter()
        audioTracks?.requestMediaDataWhenReady(on: self.queue) {
            while (!audioEnd && audioTracks!.isReadyForMoreMediaData){
                if let sampleBuffer = self.audioOutput.copyNextSampleBuffer(){
                    audioTracks?.append(sampleBuffer)
                    continue
                }else{
                    audioEnd = true
                    break
                }
            }
            if audioEnd{
                audioTracks?.markAsFinished()
                self.group.leave()
            }
        }
        self.group.notify(queue: DispatchQueue.global(), execute: {
            self.writer?.finishWriting {
                callback(url,self.writer!.status)
                self.finish()
            }
        })
    }
    
    class func fileCreate(name:String,ext:String) throws->URL{
        let outUrl = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(name).appendingPathExtension(ext)
        if FileManager.default.fileExists(atPath: outUrl.path){
            try FileManager.default.removeItem(at: outUrl)
        }
        return outUrl
    }
    
    func loadAsset(type:AVMediaType,setting:[String:Any]?)->AVAssetWriterInput?{
        guard let w = self.writer else { return nil }
        let a = AVAssetWriterInput(mediaType: type, outputSettings: setting)
        if(w.canAdd(a)){
            w.add(a)
            return a
        }
        return nil
    }
    public var startTime:CMTime = .zero
}


public class CokeAudioMixer{
    
    public var param:[AVMutableAudioMixInputParameters] = []
    public func addAudioTrack(track:AVAssetTrack){
        let a = AVMutableAudioMixInputParameters(track: track)
        self.param.append(a)
    }
    public func export(){
        let all = AVMutableAudioMix()
        all.inputParameters = param
    }
}
