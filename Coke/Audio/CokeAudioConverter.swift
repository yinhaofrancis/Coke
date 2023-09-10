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
        return CokeAudioOutputBuffer(time: buffer.time, data: Data(bytes: outpointer, count: Int(outbuff.mBuffers.mDataByteSize)), numberOfChannel: self.destination.mChannelsPerFrame, packetDescriptions: [packets.pointee], description: self.destination)
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
        return CokeAudioOutputBuffer(time: buffer.time, data: Data(bytes: outpointer, count: Int(outbuff.mBuffers.mDataByteSize)), numberOfChannel: self.destination.mChannelsPerFrame, packetDescriptions: [packets.pointee], description: self.destination)
    }
    public func reset(){
        AudioConverterReset(self.converter)
    }
    deinit{
        AudioConverterDispose(self.converter)
    }
    public var bitRate:UInt32{
        set{
            var value:UInt32 = newValue
            AudioConverterSetProperty(self.converter, kAudioConverterEncodeBitRate, UInt32(MemoryLayout<UInt32>.size), &value)
        }
        get{
            var value:UInt32 = 0
            var count:UInt32 = 0
            AudioConverterGetProperty(self.converter, kAudioConverterEncodeBitRate, &count, &value)
            return value
        }
    }
}




public class CokeFilmAudioEncodeAAC {

    public let source:AVAudioFormat
    
    public let destination:AVAudioFormat
    
    public let convert : AVAudioConverter
    
    public init?(source:AVAudioFormat,destination:AVAudioFormat){
        self.source = source
        self.destination = destination
        guard let cv = AVAudioConverter(from: source, to: destination) else { return nil }
        self.convert = cv

    }
    
    public func encode(pcm:AVAudioPCMBuffer)->AVAudioCompressedBuffer{
        let outBuffer = AVAudioCompressedBuffer(format: destination,
                                                    packetCapacity: 8,
                                                maximumPacketSize: self.convert.maximumOutputPacketSize)
        var e:NSError?
        self.convert.convert(to: outBuffer, error: &e) { c, s in
            s.pointee = AVAudioConverterInputStatus.haveData
            return pcm
        }
        return outBuffer
    }
    public func encode(sample:CMSampleBuffer)->CMSampleBuffer?{
        guard let sampleAf = sample.formatDescription else { return nil }
        guard let list = sample.audioBufferList else { return nil  }
        var mlist = list
        if #available(iOS 15.0, *) {
            guard let pcm = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(cmAudioFormatDescription: sampleAf), bufferListNoCopy: &mlist) else { return nil }
            let compress = self.encode(pcm: pcm)
            let alist = compress.audioBufferList
            guard let data = Data(bytes: alist.pointee.mBuffers.mData!, count: Int(alist.pointee.mBuffers.mDataByteSize)).blockBuffer else { return nil }
            var buffer:CMSampleBuffer?
            CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: nil, dataBuffer: data, formatDescription: self.destination.formatDescription, sampleCount: CMItemCount(compress.packetCount), presentationTimeStamp: sample.presentationTimeStamp, packetDescriptions: compress.packetDescriptions, sampleBufferOut: &buffer)
            return buffer
        }
        return nil
    }
    
}


