//
//  CokeAudioConverter.swift
//  Coke
//
//  Created by wenyang on 2023/9/10.
//

import Foundation
import AVFoundation



public class CokeAudioConverter{
    
    public let source:AudioStreamBasicDescription
    
    public let destination:AudioStreamBasicDescription
    
    public let converter:AudioConverterRef
    
    public convenience init(encode:AudioStreamBasicDescription,
                            to:AudioStreamBasicDescription = CokeAudioConfig.shared.aacAudioStreamBasicDescription) throws{
        try self.init(source: encode, destination: to)
    }
    
    public convenience init (decode:AudioStreamBasicDescription,toSampleRate:Float64? = nil,mChannelsPerFrame:UInt32 = 1) throws{
        let dest = CokeAudioConfig.shared.pcmAudioStreamBasicDescription(mFrameRate: toSampleRate ?? decode.mSampleRate, mChannelsPerFrame: mChannelsPerFrame)
        try self.init(source: decode, destination: dest)
    }
    
    public convenience init (resample:AudioStreamBasicDescription,sampleRate:Float64) throws{
        var dest = resample
        dest.mSampleRate = sampleRate
        try self.init(source: resample, destination: dest)
    }

    public init(source:AudioStreamBasicDescription,destination:AudioStreamBasicDescription) throws{
        self.source = source
        var sour = source
        self.destination = destination
        var dest = destination
        let desc = CokeAudioConverter.converterClassMaker(format: [
            kAudioFormatMPEG4AAC,
            kAudioFormatFLAC
        ], converterType: kAudioEncoderComponentType)
        var conv:AudioConverterRef?
        let e = AudioConverterNewSpecific(&sour, &dest, UInt32(desc.count), desc, &conv)
        if conv == nil {
            throw NSError(domain: "create converter fail(\(e)", code: Int(e))
        }
        self.converter = conv!
    }
    

    public func encode(buffer: CokeAudioOutputBuffer)->CokeAudioOutputBuffer?{
        
        var inputPacketNum:UInt32 = 1
 
        var newIn = buffer.data
        
        guard let inpoint = newIn.mutableRawPointer().baseAddress else { return nil }
        
        let inbuffer = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: buffer.numberOfChannel, mDataByteSize: UInt32(buffer.data.count), mData: inpoint))
        
        let inb = CokeAudioInputBuffer(buffer: inbuffer, numberOfChannel: buffer.numberOfChannel, source: self.source,packetDescriptions: buffer.packetDescriptions ?? [])
        
        let outpointer = UnsafeMutablePointer<UInt8>.allocate(capacity: buffer.data.count)
        defer{
            outpointer.deallocate()
        }

        var outbuff = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: buffer.numberOfChannel, mDataByteSize: UInt32(buffer.data.count), mData: outpointer))
        
        let packets:UnsafeMutablePointer<AudioStreamPacketDescription> = .allocate(capacity: 1)
        defer {
            packets.deallocate()
        }
        AudioConverterFillComplexBuffer(self.converter, { c, countOfPacket, inbuffer, packetDesc, userData in
            let inbuff = Unmanaged<CokeAudioInputBuffer>.fromOpaque(userData!).takeUnretainedValue()
            inbuffer.pointee.mNumberBuffers = 1
            packetDesc?.pointee = nil
            inbuffer.pointee.mBuffers.mDataByteSize = inbuff.buffer.mBuffers.mDataByteSize
            inbuffer.pointee.mBuffers.mData = inbuff.buffer.mBuffers.mData
            countOfPacket.pointee = inbuff.buffer.mBuffers.mDataByteSize / inbuff.source.mBytesPerPacket
            return noErr
        }, Unmanaged<CokeAudioInputBuffer>.passUnretained(inb).toOpaque(), &inputPacketNum, &outbuff, packets)
        if(outbuff.mBuffers.mDataByteSize < 10){
            return nil;
        }
        return CokeAudioOutputBuffer(time: buffer.time, data: Data(bytes: outpointer, count: Int(outbuff.mBuffers.mDataByteSize)), numberOfChannel: self.destination.mChannelsPerFrame, packetDescriptions: [packets.pointee], description: self.destination)
    }
    
    public func decode(buffer: CokeAudioOutputBuffer)->CokeAudioOutputBuffer?{
        
        var inputPacketNum:UInt32 = self.source.mFramesPerPacket
        var newIn = buffer.data
        guard let inpoint = newIn.mutableRawPointer().baseAddress else { return nil }
        
        let inbuffer = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: buffer.numberOfChannel, mDataByteSize: UInt32(buffer.data.count), mData: inpoint))
        
        let inb = CokeAudioInputBuffer(buffer: inbuffer, numberOfChannel: buffer.numberOfChannel, source: self.source,packetDescriptions: buffer.packetDescriptions ?? [])
        let max = 1024 * 1024
        let outpointer = UnsafeMutablePointer<UInt8>.allocate(capacity: max)
        defer{
            outpointer.deallocate()
        }

        var outbuff = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: buffer.numberOfChannel, mDataByteSize:UInt32(max) , mData: outpointer))
        
        let packets:UnsafeMutablePointer<AudioStreamPacketDescription> = .allocate(capacity: 1)
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


