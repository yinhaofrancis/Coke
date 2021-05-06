//
//  CokeAudio.swift
//  CokeAudio
//
//  Created by hao yin on 2021/3/26.
//

import Foundation
import AudioToolbox
import AVFoundation

public class CokeAudioRecorder:AudioProducerProtocol{
    var audioQueue:AudioQueueRef?
    var threadQueue:DispatchQueue
    var audioStreamDescription:AudioStreamBasicDescription
    var buffers:[AudioQueueBufferRef] = []
    var workingBuffers:Set<AudioQueueBufferRef>
    private func createBuffer(index:NSInteger){
        let c = self.audioStreamDescription.mBytesPerPacket * 512;
        var buffer:AudioQueueBufferRef?
        AudioQueueAllocateBuffer(self.audioQueue!, c, &buffer)
        guard let buff = buffer else{ return }
        self.buffers.append(buff)
    }
    private func configAudioBuffers(){
        if(self.buffers.count == 0){
            for i in 0 ..< 10 {
                self.createBuffer(index:i)
            }
        }
        for i in self.buffers {
            AudioQueueEnqueueBuffer(self.audioQueue!, i, 0, nil)
            self.workingBuffers.insert(i)
        }
    }
    private func createAudioQueue()->Bool{
        let status = AudioQueueNewInputWithDispatchQueue(&self.audioQueue, &self.audioStreamDescription, 0, self.threadQueue, { (queue, audio, time, flag, disc) in
            if(audio.pointee.mAudioDataByteSize > 0){
                let data = Data(bytes: audio.pointee.mAudioData, count: Int(audio.pointee.mAudioDataByteSize))
                let a:AudioTimeStamp = time.pointee
                self.output?.handleAudioBuffer(node:self, buffer: CokeAudioBuffer(data: data, time: a, audioStreamPacketDescription: disc?.pointee))
            }
            
            if self.isRuning{
                AudioQueueEnqueueBuffer(self.audioQueue!, audio, 0, nil)
            }else{
                self.workingBuffers.remove(audio)
            }
        })
        
        if errSecSuccess != status {
            print("error code \(status)")
            return false
        }
        
        return true
    }
    
    
    public weak var output:AudioOutputProtocol?{
        willSet{
            self.threadQueue.sync {
                newValue?.handleStreamDescription(node: self, description: self.audioStreamDescription)
            }
        }
    }
    
    
    
    
    
    public init(audioStreamDescription:AudioStreamBasicDescription = CokeAudioRecorder.PCMFloatStream) throws {
        self.threadQueue = DispatchQueue(label: "CokeAudioRecorder.threadQueue")
        self.audioStreamDescription = audioStreamDescription
        self.workingBuffers = Set()
        if !self.createAudioQueue(){
            throw NSError(domain: "create Audio Queue Sevice fail", code: 0, userInfo: nil)
        }
    }
    public func start() {
        if(self.isRuning == false){
            CokeAudioRecorder.requestAuth { (a) in
                if(a){
                    self.configAudioBuffers()
                    AudioQueueStart(self.audioQueue!, nil)
                }
            }
        }else {
            AudioQueueFlush(self.audioQueue!)
            self.configAudioBuffers()
            if errSecSuccess == AudioQueueStart(self.audioQueue!, nil){
                print("ok");
            }
        }
    }
    public var isRuning:Bool{
        get {
            var c:UInt32 = 0
            var data:UInt32 = 0
            guard let queue = self.audioQueue else { return false}
            AudioQueueGetProperty(queue, kAudioQueueProperty_IsRunning, &data, &c);
            return data != 0
        }
    }
    public func end(){
        guard let queue = self.audioQueue else { return }
        AudioQueueStop(queue, true)
        self.output?.handleStreamFinish()
    }
    public func pause(){
        guard let queue = self.audioQueue else { return }
        AudioQueuePause(queue)
    }
    public var volume:Float{
        set{
            var v = newValue
            guard let queue = self.audioQueue else { return }
            AudioQueueSetProperty(queue, kAudioQueueParam_Volume, &v, UInt32(MemoryLayout<Float>.size))
        }
        get{
            var v:Float = 0
            var c:UInt32 = 0
            guard let queue = self.audioQueue else { return 0}
            AudioQueueGetProperty(queue, kAudioQueueParam_Volume, &v, &c)
            return v
        }
    }
    
   
    public static var PCMFloatStream:AudioStreamBasicDescription = {
        
        let bitsPerChanel:UInt32 = UInt32(MemoryLayout<Float>.size) * 8
        let channelsPerFrame:UInt32 = 2
        let framesPerPacket:UInt32 = 1
        return AudioStreamBasicDescription(mSampleRate: 48000,
                                               mFormatID: kAudioFormatLinearPCM,
                                               mFormatFlags:  kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
                                               mBytesPerPacket: channelsPerFrame * UInt32(MemoryLayout<Float>.size) * framesPerPacket,
                                               mFramesPerPacket: framesPerPacket,
                                               mBytesPerFrame: channelsPerFrame * UInt32(MemoryLayout<Float>.size),
                                               mChannelsPerFrame: channelsPerFrame,
                                               mBitsPerChannel: bitsPerChanel,
                                               mReserved: 0)
    }()
    public static var PCMStream:AudioStreamBasicDescription = {
        
        let bitsPerChanel:UInt32 = UInt32(MemoryLayout<Int16>.size) * 8
        let channelsPerFrame:UInt32 = 2
        let framesPerPacket:UInt32 = 1
        return AudioStreamBasicDescription(mSampleRate: 48000,
                                               mFormatID: kAudioFormatLinearPCM,
                                               mFormatFlags:  kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
                                               mBytesPerPacket: channelsPerFrame * UInt32(MemoryLayout<Int16>.size) * framesPerPacket,
                                               mFramesPerPacket: framesPerPacket,
                                               mBytesPerFrame: channelsPerFrame * UInt32(MemoryLayout<Int16>.size),
                                               mChannelsPerFrame: channelsPerFrame,
                                               mBitsPerChannel: bitsPerChanel,
                                               mReserved: 0)
    }()
    
    public static func requestAuth(callback:@escaping (Bool)->Void){
        if AVCaptureDevice .authorizationStatus(for: .audio) == .notDetermined{
            AVCaptureDevice.requestAccess(for: .audio) { (a) in
                DispatchQueue.main.async {
                    callback(a)
                }
            }
        }else{
            if(AVCaptureDevice.authorizationStatus(for: .audio) == .authorized){
                callback(true)
            }else{
                callback(false)
            }
        }
    }
    deinit {
        AudioQueueDispose(self.audioQueue!, true)
        self.buffers.forEach { (i) in
            AudioQueueFreeBuffer(self.audioQueue!, i)
        }
    }
}
