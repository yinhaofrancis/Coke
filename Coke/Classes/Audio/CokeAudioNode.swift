//
//  CokeAudioNode.swift
//  CokeAudio
//
//  Created by hao yin on 2021/3/26.
//

import Foundation
import AudioToolbox
import AVFoundation
public protocol AudioOutputProtocol:AnyObject {
    
    func handleAudioBuffer(node:AudioNodeProtocol, buffer:CokeAudioBuffer)
    
    func handleStreamDescription(node:AudioNodeProtocol,description:AudioStreamBasicDescription)
    
    func handleStreamFinish()
}

public protocol AudioInputProtocol:AnyObject {
    
    var description: AudioStreamBasicDescription { get }
    
    func getNextAudioBuffer()->CokeAudioBuffer?
    
    var hasNext:Bool { get }
    
}

public protocol AudioNodeProtocol:AnyObject {
    var isRuning:Bool { get }

}

public protocol AudioProducerProtocol:AudioNodeProtocol {
    
    
    
    var output:AudioOutputProtocol? { get }
    
    
    
}


public protocol AudioConsumerProtocol:AudioNodeProtocol {
    
    var input:AudioInputProtocol? { get }
    
}

public struct CokeAudioBuffer:CustomDebugStringConvertible{
    public var debugDescription: String{
        return "data = \(data) \ntime = \(time) \npacketDescription = \(String(describing: audioStreamPacketDescription))"
    }
    
    public var data:Data
    public var time:AudioTimeStamp
    public var audioStreamPacketDescription:AudioStreamPacketDescription?
    
}


public class CokeAudioMemoryCache:AudioOutputProtocol,AudioInputProtocol{
    public func handleStreamFinish() {
        guard let fid = self.fileid else { return }
        AudioFileClose(fid)
        self.fileid = nil
    }
    
    public var hasNext: Bool{
        self.buffers.count > 0
    }
    
    public func getNextAudioBuffer() -> CokeAudioBuffer? {
        if(self.buffers.count > 0){
            return self.buffers.remove(at: 0)
        }
        return nil
    }

    
    public var outPut: AudioOutputProtocol?
    

    public var fileid:AudioFileID?
        
    public var description:AudioStreamBasicDescription = AudioStreamBasicDescription()
    
    
    public var buffers:[CokeAudioBuffer] = []
    
    public func handleAudioBuffer(node: AudioNodeProtocol, buffer:CokeAudioBuffer) {
        print(buffer)
        self.buffers.append(buffer)
//        var oack = buffer.audioStreamPacketDescription
//        var io:UInt32 = 1
//        let bufferp = UnsafeMutablePointer<UInt8>.allocate(capacity: buffer.data.count);
//        buffer.data.copyBytes(to: bufferp, count: buffer.data.count)
//        guard let fid = self.fileid else { return }
//        AudioFileWritePackets(fid, false, UInt32(buffer.data.count), &oack, Int64(self.buffers.count - 1), &io, bufferp)
//        bufferp.deallocate()
        
    }
    public var fileUrl:URL{
        let a = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("a").appendingPathExtension("m4a")
//        FileManager.default.createFile(atPath: a.path, contents: nil, attributes: nil)
        return a
    }
    
    public func handleStreamDescription(node: AudioNodeProtocol, description: AudioStreamBasicDescription) {
        self.description = description
//        AudioFileSetProperty(self.fileid!, kAudioFilePropertyDataFormat, UInt32(MemoryLayout.size(ofValue: self.description)), &self.description)
        try? FileManager.default.removeItem(at: self.fileUrl)
        let aa = AudioFileCreateWithURL(self.fileUrl as CFURL, kAudioFileAAC_ADTSType, &self.description, AudioFileFlags.dontPageAlignAudioData, &self.fileid)
        print(aa)
    }
    public init(){
//        let aa = AudioFileOpenURL(self.fileUrl as CFURL, .writePermission, kAudioFileM4AType, &self.fileid)
        
    }
    
}

@propertyWrapper
public struct CokeLock<T:AnyObject> {
    public var wrappedValue:T{
        get{
            return self.inner
        }
        set{
            self.lock()
            self.inner = newValue
            self.unlock()
        }
    }
    public init(wrappedValue:T) {
        self.inner = wrappedValue
    }
    private var inner:T
    private var sem = DispatchSemaphore(value: 1)
    
    public var projectedValue:CokeLock{
        return self
    }
    public func unlock(){
        sem.signal()
    }
    public func lock(){
        sem.wait()
    }
    public func call(callback:()->Void){
        self.lock()
        callback()
        self.unlock()
    }
    
}



public struct BitData {
    public var bytes:[UInt8] = [];
    public subscript(index:UInt32)->Bool{
        get{
            if self.check(index: index){
                return false
            }else{
                let v = self.bytes[Int(self.indexTransform(index: index))]
                let offset = self.indexOffetTransform(index: index)
                return ((((v >> offset) << 7) >> 7) != 0)
            }
        }
        mutating set{
            self.fill(index: index)
            let offset = self.indexOffetTransform(index: index)
            let bindex = Int(self.indexTransform(index: index))
            let v = self.bytes[bindex]
            let result = UInt8(1) << offset & v
            self.bytes[bindex] = result
        }
    }
    private func indexTransform(index:UInt32)->UInt32{
        return index / 8
    }
    private func indexOffetTransform(index:UInt32)->UInt32{

        return index % 8
    }
    private func check(index:UInt32)->Bool{
        let byteIndex = self.indexTransform(index: index)
        if byteIndex >= self.bytes.count{
            return false
        }
        return true
    }
    private mutating func fill(index:UInt32){
        let byteIndex = self.indexTransform(index: index)
        for _ in 0 ... (Int(byteIndex) - self.bytes.count) {
            self.bytes.append(0)
        }
    }
}
