//
//  CokeAudioConverter.swift
//  Coke
//
//  Created by wenyang on 2023/9/10.
//

import Foundation
import AVFoundation



public class CokeAudioConverterAAC{
    
    public let source:AudioStreamBasicDescription
    public let destination:AudioStreamBasicDescription
    
    public let converter:AudioConverterRef
    
    public init?(encode:AudioStreamBasicDescription){
        var sour = encode
        self.source = sour
        var dest = CokeAudioConfig.shared.aacAudioStreamBasicDescription
        self.destination = dest
        let desc = CokeAudioConverterAAC.converterClassMaker(format: [
            kAudioFormatMPEG4AAC
        ], converterType: kAudioEncoderComponentType)
        var conv:AudioConverterRef?
        AudioConverterNewSpecific(&sour, &dest, UInt32(desc.count), desc, &conv)
        if conv == nil {
            return nil
        }
        self.converter = conv!
    }
    
    static func converterClassMaker(format:[AudioFormatID],converterType:UInt32)->[AudioClassDescription] {
        format.map { i in
            [AudioClassDescription(
            mType: converterType,
            mSubType: i,
            mManufacturer: kAppleSoftwareAudioCodecManufacturer),
            AudioClassDescription(
            mType: converterType,
            mSubType: i,
            mManufacturer: kAppleHardwareAudioCodecManufacturer)]
        }.flatMap{$0}
    }
    public init?(decode:AudioStreamBasicDescription){
        var sour = decode
        self.source = sour
        var dest = CokeAudioConfig.shared.pcmAudioStreamBasicDescription(mFrameRate: decode.mSampleRate)
        self.destination = dest
        
        let desc = CokeAudioConverterAAC.converterClassMaker(format: [
            kAudioFormatMPEG4AAC
        ], converterType: kAudioDecoderComponentType)
        var conv:AudioConverterRef?
        AudioConverterNewSpecific(&sour, &dest, UInt32(desc.count), desc, &conv)
        if conv == nil {
            return nil
        }
        self.converter = conv!
    }
    
    public func encode(sample:CMSampleBuffer)->CMSampleBuffer?{
        guard let pcm = sample.pcm else { return nil }
        let source = CokeAudioOutputBuffer(time: .init(), data: pcm, numberOfChannel: 1)
        guard let destination = self.encode(buffer: source) else { return nil }
        return destination.createSampleBuffer(destination: self.destination, presentationTimeStamp: sample.presentationTimeStamp)
    }
    public func encode(buffer: CokeAudioOutputBuffer)->CokeAudioOutputBuffer?{
        
        var inputPacketNum:UInt32 = 1
 
        let inpoint = UnsafeMutablePointer<UInt8>.allocate(capacity: buffer.data.count)
        defer{
            inpoint.deallocate()
        }
        buffer.data.copyBytes(to: inpoint, count: buffer.data.count)
        
        let inbuffer = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: buffer.numberOfChannel, mDataByteSize: UInt32(buffer.data.count), mData: inpoint))
        
        let inb = CokeAudioInputBuffer(buffer: inbuffer, numberOfChannel: buffer.numberOfChannel, source: self.source,packetDescriptions: buffer.packetDescriptions ?? [])
        
        let outpointer = UnsafeMutablePointer<UInt8>.allocate(capacity: buffer.data.count)
        
        defer{
            outpointer.deallocate()
        }

        var outbuff = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: buffer.numberOfChannel, mDataByteSize: UInt32(buffer.data.count), mData: outpointer))
        
        let packets:UnsafeMutablePointer<AudioStreamPacketDescription> = .allocate(capacity: 64)
        defer {
            packets.deallocate()
        }
        AudioConverterFillComplexBuffer(self.converter, { c, countOfPacket, inbuffer, packetDesc, userData in
            let inbuff = Unmanaged<CokeAudioInputBuffer>.fromOpaque(userData!).takeUnretainedValue()
            inbuffer.pointee.mNumberBuffers = 1
            packetDesc?.pointee = nil
            inbuffer.pointee.mBuffers.mDataByteSize = inbuff.buffer.mBuffers.mDataByteSize
            inbuffer.pointee.mBuffers.mData = inbuff.buffer.mBuffers.mData
            if(inbuff.source.mFormatID == kAudioFormatLinearPCM){
                countOfPacket.pointee = inbuff.buffer.mBuffers.mDataByteSize / inbuff.source.mBytesPerPacket
            }else{
                countOfPacket.pointee = inbuff.numberOfPacket;
                packetDesc?.pointee = inbuff.packetDescriptions
            }
            return noErr
        }, Unmanaged<CokeAudioInputBuffer>.passUnretained(inb).toOpaque(), &inputPacketNum, &outbuff, packets)
        print(inputPacketNum)
        return CokeAudioOutputBuffer(time: buffer.time, data: Data(bytes: outpointer, count: Int(outbuff.mBuffers.mDataByteSize)), numberOfChannel: self.destination.mChannelsPerFrame,packetDescriptions: [packets.pointee])
    }
    
    public func decode(buffer: CokeAudioOutputBuffer)->CokeAudioOutputBuffer?{
        
        var inputPacketNum:UInt32 = 1024
        let inpoint = UnsafeMutablePointer<UInt8>.allocate(capacity: buffer.data.count)
        defer {
            inpoint.deallocate()
        }
        buffer.data.copyBytes(to: inpoint, count: buffer.data.count)
        
        let inbuffer = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: buffer.numberOfChannel, mDataByteSize: UInt32(buffer.data.count), mData: inpoint))
        
        let inb = CokeAudioInputBuffer(buffer: inbuffer, numberOfChannel: buffer.numberOfChannel, source: self.source,packetDescriptions: buffer.packetDescriptions ?? [])
        
        let outpointer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024 * 1024)
        defer{
            outpointer.deallocate()
        }

        var outbuff = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: buffer.numberOfChannel, mDataByteSize: UInt32( 1024 * 1024), mData: outpointer))
        
        let packets:UnsafeMutablePointer<AudioStreamPacketDescription> = .allocate(capacity: 64)
        defer {
            packets.deallocate()
        }
        AudioConverterFillComplexBuffer(self.converter, { c, countOfPacket, inbuffer, packetDesc, userData in
            let inbuff = Unmanaged<CokeAudioInputBuffer>.fromOpaque(userData!).takeUnretainedValue()
            inbuffer.pointee.mNumberBuffers = 1
            inbuffer.pointee.mBuffers.mDataByteSize = inbuff.buffer.mBuffers.mDataByteSize
            inbuffer.pointee.mBuffers.mData = inbuff.buffer.mBuffers.mData
            countOfPacket.pointee = inbuff.numberOfPacket;
            packetDesc?.pointee = inbuff.packetDescriptions
            return noErr
        }, Unmanaged<CokeAudioInputBuffer>.passUnretained(inb).toOpaque(), &inputPacketNum, &outbuff, packets)
        print(inputPacketNum)
        return CokeAudioOutputBuffer(time: buffer.time, data: Data(bytes: outpointer, count: Int(outbuff.mBuffers.mDataByteSize)), numberOfChannel: self.destination.mChannelsPerFrame,packetDescriptions: [packets.pointee])
    }
    public func reset(){
        AudioConverterReset(self.converter)
    }
}
