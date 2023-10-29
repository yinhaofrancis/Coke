//
//  File.swift
//
//
//  Created by wenyang on 2023/7/2.
//

import AudioToolbox
import AVFoundation
import Accelerate
public enum PackSampleCount:UInt32{
    case sample1024 = 1024
}

public struct AudioOutBufferPacket{
    
    public var data:Data
    
    public var audioStreamPacketDescription:AudioStreamPacketDescription
    
    public init(data: Data, audioStreamPacketDescription: AudioStreamPacketDescription) {
        self.data = data
        self.audioStreamPacketDescription = audioStreamPacketDescription
    }
}

public struct AudioOutBuffer{
    
    public var packets:[AudioOutBufferPacket]
    
    public var audioStreamBasicDescription:AudioStreamBasicDescription
    
    public init(packets: [AudioOutBufferPacket], audioStreamBasicDescription: AudioStreamBasicDescription) {
        self.packets = packets
        self.audioStreamBasicDescription = audioStreamBasicDescription
    }
}

public protocol AudioDecode{
    func decode(audioPackets:[Data])->Data
}

public protocol AudioEncode{
    func encode(pcmBuffer:Data)->AudioOutBuffer
}

public func getProperty<T>(value:T,callback:(_ ioPropertyDataSize: UnsafeMutablePointer<UInt32>,_ outPropertyData: UnsafeMutableRawPointer)->Void)->T{
    var size:UInt32 = UInt32(MemoryLayout<T>.size)
    var valuet = value
    callback(&size,&valuet)
    return valuet
}

public func setProperty<T>(value:T,callback:(_ inPropertyDataSize: UInt32, _ inPropertyData: UnsafeRawPointer)->Void){
    let size:UInt32 = UInt32(MemoryLayout<T>.size)
    var valuet = value
    callback(size,&valuet)
}


extension CMSampleBuffer {
    public var pcm:Data?{
        guard let buffer = self.audioBufferList else { return nil }
        guard let pointer = buffer.mBuffers.mData else { return nil }
        return Data(bytes: pointer, count: Int(buffer.mBuffers.mDataByteSize))
    }
    public var audioBufferList:AudioBufferList?{
        return self.audioBlockBuffer?.1
    }
    public var audioBlockBuffer:(CMBlockBuffer,AudioBufferList)?{
        guard self.mediaType == kCMMediaType_Audio else {
            return nil
        }
        var audioBufferList = AudioBufferList()
        var blockBuffer: CMBlockBuffer?
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            self,
            bufferListSizeNeededOut: nil,
            bufferListOut: &audioBufferList,
            bufferListSize: MemoryLayout.stride(ofValue: audioBufferList),
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: &blockBuffer)
        guard let blockBuffer else { return nil }
        return (blockBuffer,audioBufferList)
        
    }
    public var packetDescription:[AudioStreamPacketDescription]{
        let pointer:UnsafeMutablePointer<UnsafePointer<AudioStreamPacketDescription>?> = .allocate(capacity: 1)
        defer{
            pointer.deallocate()
        }
        var count:Int = 0
        CMSampleBufferGetAudioStreamPacketDescriptionsPtr(self, packetDescriptionsPointerOut: pointer, sizeOut: &count)
        if(count == 0){
            return []
        }else{
            return (0 ..< count).map { i in
                pointer.pointee!.advanced(by: i).pointee
            }
        }
    }
}

public struct CokeAudioOutputBuffer{
    public var time:CMTime
    public var data:Data
    public var numberOfChannel:UInt32
    public var packetDescriptions:[AudioStreamPacketDescription]?
    public var description:AudioStreamBasicDescription
    public init(time: CMTime, data: Data, numberOfChannel: UInt32, packetDescriptions: [AudioStreamPacketDescription]? = nil, description: AudioStreamBasicDescription) {
        self.time = time
        self.data = data
        self.numberOfChannel = numberOfChannel
        self.packetDescriptions = packetDescriptions
        self.description = description
    }
    public func createSampleBuffer()->CMSampleBuffer?{
        do{
            let format = try CMAudioFormatDescription(audioStreamBasicDescription: self.description)
            var result:CMSampleBuffer?
            CMAudioSampleBufferCreateWithPacketDescriptions(allocator: nil, dataBuffer: self.data.audioBlockBuffer, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: format, sampleCount: self.packetDescriptions?.count ?? 1, presentationTimeStamp: self.time, packetDescriptions: self.packetDescriptions ?? [], sampleBufferOut: &result)
            return result
        }catch{
            return nil
        }
    }
    public func createPCMSampleBuffer(destination:AudioStreamBasicDescription)->CMSampleBuffer?{
        do{
            let format = try CMAudioFormatDescription(audioStreamBasicDescription: destination)
            var result:CMSampleBuffer?
            let a = self.data.audioBlockBuffer
            CMAudioSampleBufferCreateWithPacketDescriptions(allocator: nil, dataBuffer: a, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: format, sampleCount: 1, presentationTimeStamp: self.time, packetDescriptions: nil, sampleBufferOut: &result)
            return result
        }catch{
            return nil
        }
    }
}
public class CokeAudioInputBuffer{
    public var buffer:AudioBufferList
    public var numberOfChannel:UInt32
    public var numberOfPacket:UInt32
    public var source:AudioStreamBasicDescription
    public var packetDescriptions:UnsafeMutablePointer<AudioStreamPacketDescription>?
    
    public init(buffer: AudioBufferList,
         numberOfChannel: UInt32,
         source: AudioStreamBasicDescription, packetDescriptions: [AudioStreamPacketDescription] = []) {
        self.buffer = buffer
        self.numberOfChannel = numberOfChannel
        self.numberOfPacket = UInt32(packetDescriptions.count)
        self.source = source
        if packetDescriptions.count > 0{
            self.packetDescriptions = UnsafeMutablePointer<AudioStreamPacketDescription>.allocate(capacity: packetDescriptions.count)
            (0 ..< packetDescriptions.count).forEach { i in
                self.packetDescriptions?[i] = packetDescriptions[i]
            }
        }
    }
    deinit {
        self.packetDescriptions?.deallocate()
    }
}

public struct CokeAudioConfig{
    public let mSampleRate:Float64
    public let mBitsPerChannel:UInt32
    public let mChannelsPerFrame:UInt32
    public let mFramesPerPacket:UInt32
    public let packSampleCount: PackSampleCount = .sample1024
    public static let shared = CokeAudioConfig(
        mSampleRate: 44100,
        mBitsPerChannel: 32,
        mChannelsPerFrame: 1,
        mFramesPerPacket: 1
    )
    
    public var pcmIntegerAudioStreamBasicDescription:AudioStreamBasicDescription{
        self.pcmAudioStreamBasicDescription(mFrameRate: self.mSampleRate, mChannelsPerFrame: self.mChannelsPerFrame)
    }
    public var pcmAudioStreamBasicDescription:AudioStreamBasicDescription{
        self.pcmAudioStreamBasicDescription(mFrameRate: self.mSampleRate, mChannelsPerFrame: self.mChannelsPerFrame,flag: kAudioFormatFlagIsFloat)
    }
    
    public func pcmAudioStreamBasicDescription(mFrameRate:Float64,
                                               mChannelsPerFrame:UInt32,
                                               flag:AudioFormatFlags = kAudioFormatFlagIsSignedInteger)->AudioStreamBasicDescription{
        let mSampleRate:Float64 = mFrameRate
        let mBitsPerChannel:UInt32 = self.mBitsPerChannel
        let mChannelsPerFrame:UInt32 = mChannelsPerFrame
        let mFramesPerPacket:UInt32 = self.mFramesPerPacket
        return AudioStreamBasicDescription(
            mSampleRate: mSampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: flag,
            mBytesPerPacket: mChannelsPerFrame * mBitsPerChannel / 8 * mFramesPerPacket,
            mFramesPerPacket: mFramesPerPacket,
            mBytesPerFrame: mChannelsPerFrame * mBitsPerChannel / 8,
            mChannelsPerFrame: mChannelsPerFrame,
            mBitsPerChannel: mBitsPerChannel, mReserved: 0)
    }
    
    public var aacAudioStreamBasicDescription:AudioStreamBasicDescription{
        return AudioStreamBasicDescription(mSampleRate: self.mSampleRate, mFormatID: kAudioFormatMPEG4AAC, mFormatFlags: 0, mBytesPerPacket: 0, mFramesPerPacket: packSampleCount.rawValue, mBytesPerFrame: 0, mChannelsPerFrame: self.mChannelsPerFrame, mBitsPerChannel: 0, mReserved: 0)
    }
    
    public var flacAudioStreamBasicDescription:AudioStreamBasicDescription{
        return AudioStreamBasicDescription(mSampleRate: self.mSampleRate, mFormatID: kAudioFormatFLAC, mFormatFlags: 0, mBytesPerPacket: 0, mFramesPerPacket: packSampleCount.rawValue, mBytesPerFrame: 0, mChannelsPerFrame: self.mChannelsPerFrame, mBitsPerChannel: 0, mReserved: 0)
    }
}
