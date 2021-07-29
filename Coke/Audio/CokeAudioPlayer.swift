//
//  CokeAudioPlayer.swift
//  CokeAudio
//
//  Created by hao yin on 2021/3/26.
//

import Foundation
import AudioToolbox
import AVFoundation


public class CokeAudioPlayer:AudioConsumerProtocol{
    
    public init(){
        
    }
    
    var threadQueue:DispatchQueue =  DispatchQueue(label: "CokeAudioPlayer.threadQueue")
    
    public weak var input: AudioInputProtocol?
    
    var len:Int64 = 0
    
    var workingBuffers:Set<AudioQueueBufferRef> = Set()
    
    var description:AudioStreamBasicDescription = AudioStreamBasicDescription()
    
    private func createBuffer(buffer:CokeAudioBuffer)->AudioQueueBufferRef?{
        
        var abuffer:AudioQueueBufferRef?
        
        let size:UInt32 = UInt32(buffer.data.count)
        
        AudioQueueAllocateBuffer(self.audioQueue!, size, &abuffer)
        guard let audio = abuffer else { return nil }
        audio.pointee.mAudioDataByteSize = UInt32(buffer.data.count)
        let temp = UnsafeMutablePointer<UInt8>.allocate(capacity: buffer.data.count)
        buffer.data.copyBytes(to: temp, count: buffer.data.count)
        memcpy(audio.pointee.mAudioData, temp, buffer.data.count)
        temp.deallocate()
        return audio
    }
    public var isRuning: Bool{
        var c:UInt32 = 0
        var data:UInt32 = 0
        AudioQueueGetProperty(self.audioQueue!, kAudioQueueProperty_IsRunning, &data, &c);
        return data != 0
    }
    
    public var audioQueue:AudioQueueRef?
        

    public func start() {
        self.len = 0
        guard let inputObj = self.input else { return }
        if self.audioQueue == nil{
            self.description = inputObj.description
            var status = AudioQueueNewOutputWithDispatchQueue(&self.audioQueue, &self.description, 0, self.threadQueue) { (aQueue, buffer) in
                self.workingBuffers.remove(buffer)
                AudioQueueFreeBuffer(aQueue, buffer)
                print("----")
                if self.isRuning == true {
                    self.enqueueBuffer(inputObj: inputObj, aQueue: aQueue)
                }
            }
            
            if status != errSecSuccess{
                print("player init fail \(status)")
            }
            
            
            
            
            self.loadBuffers(count:0, inputObj: inputObj)
            guard let queue = self.audioQueue else { return }
            if(self.description.mFormatID != kAudioFormatLinearPCM){
                status = AudioQueuePrime(queue, 1024, nil)
                if status != errSecSuccess{
                    print("player prime fail \(status)")
                }
            }
            status =  AudioQueueStart(queue, nil)
            
            if status != errSecSuccess{
                print("player start fail \(status)")
            }
        }else{
            
            
            if self.workingBuffers.count == 0{
                self.loadBuffers(count:0, inputObj: inputObj)
            }
            guard let queue = self.audioQueue else { return }
            AudioQueueStart(queue, nil)
        }
        
    }
    func loadBuffers(count:Int = 0,inputObj:AudioInputProtocol){
        if(count == 0){
            while inputObj.hasNext {
                self.enqueueBuffer(inputObj: inputObj, aQueue: self.audioQueue!)
            }
        }
        for _ in 0 ..< count {
            self.enqueueBuffer(inputObj: inputObj, aQueue: self.audioQueue!)
        }
    }
    func enqueueBuffer(inputObj:AudioInputProtocol,aQueue:AudioQueueRef){
        guard let a = inputObj.getNextAudioBuffer() else { return }
        guard let newbuffer =  self.createBuffer(buffer: a) else { return }
        if let dsc = a.audioStreamPacketDescription{
            var desc = dsc
            desc.mStartOffset = len;
            AudioQueueEnqueueBuffer(aQueue, newbuffer, 0, &desc)
        }else{
            AudioQueueEnqueueBuffer(aQueue, newbuffer, 0, nil)
        }
        
        self.workingBuffers.insert(newbuffer);
    }
    
    public func end() {
        guard let queue = self.audioQueue else { return  }
        AudioQueueStop(queue,true)
    }
    
    public func pause() {
        guard let queue = self.audioQueue else { return  }
        AudioQueuePause(queue)
    }
    deinit {
        
        guard let queue = self.audioQueue else { return  }
        AudioQueueDispose(queue, true)
    }
    
}
