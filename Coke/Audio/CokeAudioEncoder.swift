//
//  CokeAudioEncoder.swift
//  Coke
//
//  Created by wenyang on 2023/9/6.
//

import Foundation
import AudioToolbox
import CoreMedia

public class CokeAudioEncoder {
    
    public let source,destination:AudioStreamBasicDescription
    
    let converter:AudioConverterRef
    
    public enum Quality:UInt32 {
        case Max                              = 0x7F
        case High                             = 0x60
        case Medium                           = 0x40
        case Low                              = 0x20
        case Min                              = 0
    }
    
    public init(source:AudioStreamBasicDescription,destination:AudioStreamBasicDescription) throws {
        var s = source
        var d = destination
        self.source = source
        self.destination = destination
        var newCon:AudioConverterRef?
        let r = AudioConverterNew(&s, &d, &newCon)
        guard let newCon else {
            print(r)
            throw NSError(domain: "转换器创建失败", code:Int(r))
        }
        self.converter = newCon
    }
    
    public var bitRate:UInt32{
        get{
            return getProperty(value: UInt32(0)) { ioPropertyDataSize, outPropertyData in
                AudioConverterGetProperty(self.converter, kAudioConverterEncodeBitRate, ioPropertyDataSize, outPropertyData)
            }
        }
        set{
            setProperty(value: newValue) { inPropertyDataSize, inPropertyData in
                AudioConverterSetProperty(self.converter, kAudioConverterEncodeBitRate, inPropertyDataSize,inPropertyData)
            }
        }
    }
    
    public var quality:Quality {
        get{
            return getProperty(value: Quality(rawValue: 0) ?? .Medium) { ioPropertyDataSize, outPropertyData in
                AudioConverterGetProperty(self.converter, kAudioConverterEncodeAdjustableSampleRate, ioPropertyDataSize, outPropertyData)
            }
        }
        set{
            setProperty(value: newValue) { inPropertyDataSize, inPropertyData in
                AudioConverterSetProperty(self.converter, kAudioConverterEncodeAdjustableSampleRate, inPropertyDataSize,inPropertyData)
            }
        }
    }
    
    public var sampleRate:Float64{
        get{
            return getProperty(value: Float64(0)) { ioPropertyDataSize, outPropertyData in
                AudioConverterGetProperty(self.converter, kAudioConverterEncodeAdjustableSampleRate, ioPropertyDataSize, outPropertyData)
            }
        }
        set{
            setProperty(value: newValue) { inPropertyDataSize, inPropertyData in
                AudioConverterSetProperty(self.converter, kAudioConverterEncodeAdjustableSampleRate, inPropertyDataSize,inPropertyData)
            }
        }
    }
  
    public func encode(pcmBuffer:Data)->AudioOutBuffer{
        let b = self.encodePackets(pcmBuffer: pcmBuffer)
        return AudioOutBuffer(packets: b, audioStreamBasicDescription: self.destination)
    }
    public func encode(sampleBuffer:CMSampleBuffer)->CMSampleBuffer?{
        guard let pcm = sampleBuffer.pcm else { return nil }
        let oout = self.encode(pcmBuffer: pcm)
        do{
            let format = try CMAudioFormatDescription(audioStreamBasicDescription: self.destination)
            let databuffer = oout.packets.reduce(into: Data()) { partialResult, ao in
                partialResult += ao.data
            }
            let desc = oout.packets.map { a in
                a.audioStreamPacketDescription
            }
            var result:CMSampleBuffer?
            CMAudioSampleBufferCreateWithPacketDescriptions(allocator: nil, dataBuffer: databuffer.audioBlockBuffer, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: format, sampleCount: oout.packets.count, presentationTimeStamp: sampleBuffer.presentationTimeStamp, packetDescriptions: desc, sampleBufferOut: &result)
            return result
        }catch{
            return nil
        }
    }
    
    deinit{
        AudioConverterReset(self.converter)
        AudioConverterDispose(self.converter)
    }
    
    public static func createAudioStreamBasicDescription(mFrameRate:Float64,
                                                         format:AudioFormatID,
                                                         channel:UInt32)->AudioStreamBasicDescription{
        return AudioStreamBasicDescription(mSampleRate: mFrameRate, mFormatID: format, mFormatFlags: 0, mBytesPerPacket: 0, mFramesPerPacket: 1024, mBytesPerFrame: 0, mChannelsPerFrame: channel, mBitsPerChannel: 0, mReserved: 0)
    }
    
    public static func aacAudioStreamBasicDescription(mFrameRate:Float64)->AudioStreamBasicDescription{
        self.createAudioStreamBasicDescription(mFrameRate: mFrameRate, format: kAudioFormatMPEG4AAC, channel: 1)
    }
}


extension CokeAudioEncoder{
    
    private func inEncode(pcm:Data)->AudioOutBufferPacket?{
        
        var pack:AudioStreamPacketDescription = .init(mStartOffset: 0, mVariableFramesInPacket: 0, mDataByteSize: 0)
        var size:UInt32 = 1
        let inbuffer = AudioEncodeBuffer(data: pcm, channel: self.source.mChannelsPerFrame, mBytesPerPacket: self.source.mBytesPerPacket)
        let destSize:UInt32 = self.maximumOutputPacketSize
        var buffer = AudioEncodeBuffer.createNewAudioBuffer(channel: self.destination.mChannelsPerFrame, count: destSize)
        
        AudioConverterFillComplexBuffer(self.converter, { c, numberOfFrame, buffer, pack, io in
            let a:AudioEncodeBuffer = Unmanaged.fromOpaque(io!).takeUnretainedValue()
            buffer.pointee.mNumberBuffers = 1;
            buffer.pointee.mBuffers = a.buffer.mBuffers
            buffer.pointee.mBuffers.mNumberChannels = 1
            numberOfFrame.pointee = a.noUsedPack;
            return noErr
        }, Unmanaged.passUnretained(inbuffer).toOpaque(), &size, &buffer, &pack)
        
        guard let mData = buffer.mBuffers.mData else {
            return nil
        }
        defer{
            buffer.mBuffers.mData?.deallocate()
        }
        return AudioOutBufferPacket(data: Data(bytes: mData, count: Int(buffer.mBuffers.mDataByteSize)), audioStreamPacketDescription: pack)
    }
    public var maximumOutputPacketSize:UInt32{
        var size:UInt32 = 0
        var result:UInt32 = 0
        AudioConverterGetProperty(self.converter, kAudioConverterPropertyMaximumOutputPacketSize, &size, &result)
        return result
    }
    
    private func encodePackets(pcmBuffer:Data)->[AudioOutBufferPacket]{
        var cur:Int = 0
        let size = self.source.mBytesPerFrame * 1024
        var result:[AudioOutBufferPacket] = []
        while(cur < pcmBuffer.count){
            let current = (cur + Int(size) < pcmBuffer.count) ? pcmBuffer[cur ..< cur + Int(size)] : pcmBuffer[cur ..<  pcmBuffer.count]
            guard let ret = self.inEncode(pcm: current) else { return [] }
            result.append(ret)
            cur += Int(size)
        }
        return result
    }
}


public class AudioEncodeBuffer{
    var buffer:AudioBufferList
    var index:UnsafeMutableRawPointer?
    var noUsedPack:UInt32
    var mBytesPerPacket:UInt32
    init(buffer: AudioBufferList,mBytesPerPacket:UInt32) {
        self.buffer = buffer
        self.mBytesPerPacket = mBytesPerPacket
        self.index = buffer.mBuffers.mData
        self.noUsedPack = buffer.mBuffers.mDataByteSize / mBytesPerPacket
    }
    convenience init(data:Data,channel:UInt32,mBytesPerPacket:UInt32){
        let pointer = UnsafeMutableRawPointer.allocate(byteCount: data.count, alignment: 8)
        data.copyBytes(to: pointer.assumingMemoryBound(to: UInt8.self), count: data.count)
        let buffer = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: channel, mDataByteSize: UInt32(data.count), mData: pointer))
        self.init(buffer: buffer,mBytesPerPacket: mBytesPerPacket)
    }
    static func createNewAudioBuffer(channel:UInt32,count:UInt32)->AudioBufferList{
        let pointer = UnsafeMutableRawPointer.allocate(byteCount: Int(count), alignment: 8)
        return AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: channel, mDataByteSize: count, mData: pointer))
    }
    deinit{
        self.buffer.mBuffers.mData?.deallocate()
    }
}

