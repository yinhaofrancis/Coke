//
//  CodeVideoSample.swift
//  Coke
//
//  Created by wenyang on 2023/9/4.
//

import AVFoundation


extension CMSampleBuffer{
    
    public var videoFormatDescription:CMVideoFormatDescription?{
        CMSampleBufferGetFormatDescription(self)
    }
    
    public var width:Int{
        guard let pixel = self.imageBuffer else { return 0 }
        return CVPixelBufferGetWidth(pixel)
    }
    public var height:Int{
        guard let pixel = self.imageBuffer else { return 0 }
        return CVPixelBufferGetHeight(pixel)
    }
    public var frame:[Data]{
        guard let cmfmt = self.videoFormatDescription else { return [] }

        if CMFormatDescriptionGetMediaType(cmfmt) != kCMMediaType_Video{
            return []
        }
        guard let blockBuffer = CMSampleBufferGetDataBuffer(self) else {
            return []
        }
        var totalLength: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        let status = CMBlockBufferGetDataPointer(blockBuffer,
                                                 atOffset: 0,
                                                 lengthAtOffsetOut: nil,
                                                 totalLengthOut: &totalLength,
                                                 dataPointerOut: &dataPointer)
        if status != kCMBlockBufferNoErr {
            return []
        }
        guard let dataPointer else { return [] }
        return Data.dataCutByHeaderLen(dataPointer: dataPointer, totalLength: totalLength)
    }

    public static var nalStartCode:Data{
        let nalHeader: [UInt8] = [0x00, 0x00, 0x00, 0x01]
        return Data(bytes: nalHeader, count: nalHeader.count)
    }
    
    
    public var isIFrame:Bool{
        
        guard let cmfmt = self.videoFormatDescription else { return false }

        if CMFormatDescriptionGetMediaType(cmfmt) != kCMMediaType_Video{
            return false
        }
        let attachments =  CMSampleBufferGetSampleAttachmentsArray(self, createIfNecessary: true) as? [[CFString: Any]]
                
        let isNotKeyFrame = (attachments?.first?[kCMSampleAttachmentKey_DependsOnOthers] as? Bool) ?? false
                
        return !isNotKeyFrame
    }
    

    
    
    public var duration:CMTime{
        return CMSampleBufferGetDuration(self)
    }
    public func setDisplayImmediately(di:Bool){
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(self,
                                                                     createIfNecessary: true) {
            let dic = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0),
                                    to: CFMutableDictionary.self)
            CFDictionarySetValue(dic,
                                 Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                                 Unmanaged.passUnretained(di ? kCFBooleanTrue : kCFBooleanFalse).toOpaque())
        }
    }
    public func setKeyFrame(keyFrame:Bool){
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(self,
                                                                     createIfNecessary: true) {
            let dic = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0),
                                    to: CFMutableDictionary.self)
            CFDictionarySetValue(dic,
                                 Unmanaged.passUnretained(kCMSampleAttachmentKey_DependsOnOthers).toOpaque(),
                                 Unmanaged.passUnretained( keyFrame ? kCFBooleanFalse : kCFBooleanTrue).toOpaque())
        }
    }
}

extension CMSampleBuffer {
    public var mediaType:CMMediaType?{
        guard let format = CMSampleBufferGetFormatDescription(self) else { return nil }
        return CMFormatDescriptionGetMediaType(format)
    }
    public var audioFormat:AudioStreamBasicDescription?{
        guard let format = CMSampleBufferGetFormatDescription(self) else { return nil }
        return CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee
    }
    
    public var paramH264Set:[Data]{
        (0 ..< self.paramH264SetCount).map { i in
            self.paramH264Set(index: i)!
        }
    }
    public var paramH264SetCount:Int{
        guard let cmvfd = self.videoFormatDescription else { return 0 }
        var count = 0
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(cmvfd, parameterSetIndex: 0, parameterSetPointerOut: nil, parameterSetSizeOut: nil, parameterSetCountOut: &count, nalUnitHeaderLengthOut: nil)
        return count
    }
    
    public func paramH264Set(index:Int)->Data?{
        guard let cmvfd = self.videoFormatDescription else { return nil }
        if(index < self.paramH264SetCount){
            var size:Int = 0
            var data:UnsafePointer<UInt8>?
            CMVideoFormatDescriptionGetH264ParameterSetAtIndex(cmvfd, parameterSetIndex: index, parameterSetPointerOut: &data, parameterSetSizeOut: &size, parameterSetCountOut: nil, nalUnitHeaderLengthOut: nil)
            return data == nil ? nil : Data(bytes: data!, count: size)
        }
        return nil
    }
    public var nalH264Unit:[Data]{
        if (self.isIFrame){
            return paramH264Set + frame
        }else{
            return frame
        }
    }
    public var timeInfo:[CMSampleTimingInfo]{
        return (0 ..< CMSampleBufferGetNumSamples(self)).map { i in
            var info:CMSampleTimingInfo = CMSampleTimingInfo()
            CMSampleBufferGetSampleTimingInfo(self, at: i, timingInfoOut: &info)
            return info
        }
    }
}

extension CMSampleBuffer{
    public var paramHEVCSetCount:Int{
        guard let cmvfd = self.videoFormatDescription else { return 0 }
        var count = 0
        CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(cmvfd, parameterSetIndex: 0, parameterSetPointerOut: nil, parameterSetSizeOut: nil, parameterSetCountOut: &count, nalUnitHeaderLengthOut: nil)
        return count
    }
    public var paramHEVCSet:[Data]{
        (0 ..< self.paramHEVCSetCount).map { i in
            self.paramHEVCSet(index: i)!
        }
    }
    
    public func paramHEVCSet(index:Int)->Data?{
        guard let cmvfd = self.videoFormatDescription else { return nil }
        if(index < self.paramHEVCSetCount){
            var size:Int = 0
            var data:UnsafePointer<UInt8>?
            CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(cmvfd, parameterSetIndex: index, parameterSetPointerOut: &data, parameterSetSizeOut: &size, parameterSetCountOut: nil, nalUnitHeaderLengthOut: nil)
            return data == nil ? nil : Data(bytes: data!, count: size)
        }
        return nil
    }
    public var nalHEVCUnit:[Data]{
        if (self.isIFrame){
            return paramHEVCSet + frame
        }else{
            return frame
        }
    }
}

extension CMBlockBuffer{
    public func creatSampleBuffer(keyframe:Bool,
                                  timingInfo:CMSampleTimingInfo?,
                                  description:CMVideoFormatDescription)->CMSampleBuffer?{
        var sampleBuffer : CMSampleBuffer?
        var _timingInfo:CMSampleTimingInfo = timingInfo ?? CMSampleTimingInfo(duration: .zero, presentationTimeStamp: .zero, decodeTimeStamp: .zero)
        let error = CMSampleBufferCreateReady(allocator: kCFAllocatorDefault,
                                  dataBuffer: self,
                                  formatDescription: description,
                                  sampleCount: 1,
                                  sampleTimingEntryCount: 1,
                                  sampleTimingArray: &_timingInfo,
                                  sampleSizeEntryCount: 0,
                                  sampleSizeArray: nil,
                                  sampleBufferOut: &sampleBuffer)
        
        guard error == noErr,
              let sampleBuffer = sampleBuffer else {
            print("fail to create sample buffer")
            return nil
        }
        
        if(timingInfo == nil){
            sampleBuffer.setDisplayImmediately(di: true)
        }
        sampleBuffer.setKeyFrame(keyFrame: keyframe)
        
        return sampleBuffer
    }
    public func append(block:CMBlockBuffer){
        CMBlockBufferAppendBufferReference(self, targetBBuf: block, offsetToData: 0, dataLength: 0, flags: .zero)
    }
}

extension Data{
    public func createUnsafeBuffer(offset:Int = 0)->UnsafeMutablePointer<UInt8>{
        let p = UnsafeMutablePointer<UInt8>.allocate(capacity: self.count + offset)
        self.copyBytes(to: p + offset, count: self.count)
        return p
    }
    public var toUInt32:UInt32{
        CFSwapInt32BigToHost(self.withUnsafeBytes { p in
            p.bindMemory(to: UInt32.self)
        }.baseAddress?.pointee ?? 0)
    }
    public var toUInt64:UInt64{
        CFSwapInt64BigToHost(self.withUnsafeBytes { p in
            p.bindMemory(to: UInt64.self)
        }.baseAddress?.pointee ?? 0)
    }
    
    public var toUInt24H:UInt32{
        CFSwapInt32BigToHost(self.withUnsafeBytes { p in
            p.bindMemory(to: UInt32.self)
        }.baseAddress?.pointee ?? 0) & 0x00ffffff
    }
    public var toUInt24L:UInt32{
        (CFSwapInt32BigToHost(self.withUnsafeBytes { p in
            p.bindMemory(to: UInt32.self)
        }.baseAddress?.pointee ?? 0) & 0xffffff00) >> 8
    }
    public var toUInt16:UInt16{
        CFSwapInt16BigToHost(self.withUnsafeBytes { p in
            p.bindMemory(to: UInt16.self)
        }.baseAddress?.pointee ?? 0)
    }
    public var toUInt8:UInt8{
        self.withUnsafeBytes { p in
            p.bindMemory(to: UInt8.self)
        }.baseAddress?.pointee ?? 0
    }
}

public struct NalUnitH264Header:ExpressibleByIntegerLiteral{
    public typealias IntegerLiteralType = UInt8
    public var content:UInt8
    public init(integerLiteral value: UInt8) {
        self.content = value
    }
    public var type:NalUnitType{
        return NalUnitType(rawValue: self.rawType) ?? .other
    }
    public var rawType:UInt8{
        return self.content & 0b00011111
    }
    public var header:UInt8{
        return (self.content & 0b01100000) >> 5
    }
    
    public enum NalUnitType:UInt8{
        case SEI = 6
        case SPS = 7
        case PPS = 8
        case SPSE = 13
        case SSPS = 15
        case IFRAME = 5
        case PFRAME = 1
        case queueEnd = 10
        case streamEnd = 11
        case other = 0
    }
    public var isVCL:Bool{
        self.rawType < 5
    }
}


public struct NalUnitHEVCHeader:ExpressibleByIntegerLiteral{
    public typealias IntegerLiteralType = UInt16
    public var content:UInt16
    public init(integerLiteral value: UInt16) {
        self.content = value
    }
    public var type:NalUnitType{
        return NalUnitType(rawValue: self.rawType) ?? .other
    }
    public var rawType:UInt8{
        return UInt8(self.content >> 8 & 0b01111110) >> 1
    }
    
    public enum NalUnitType:UInt8{
        case VPS = 32
        case SPS = 33
        case PPS = 34
        case AUD = 35
        case EOS = 36
        case EOB = 37
        case PSEI = 39
        case SSEI = 40
        case IFRAME_W = 19
        case IFRAME_N = 20
        case CRA = 21
        case PFRAME_N = 0
        case PFRAME_R = 1
        case other = 63
    }
    public var isVCL:Bool{
        self.rawType < 32
    }
}

extension Data{
    public var nalUnitH264Header:NalUnitH264Header{
        NalUnitH264Header(integerLiteral: self.toUInt8)
    }
    public var nalUnitHEVCHeader:NalUnitHEVCHeader{
        NalUnitHEVCHeader(integerLiteral: self.toUInt16)
    }
    public var nalu:[Data]{
        var cur = 0
        var header = -1
        var datas:[Data] = []
        while(cur < self.count - 3){
            if(self[cur] == 0 && self[cur + 1] == 0 && self[cur + 2] == 1){
                if(header < 0){
                    header = cur + 3
                    cur = cur + 3
                }else {
                    datas.append(self[header ..< cur])
                    header = cur + 3
                    cur += 3
                }
            }else{
                cur += 1
            }
        }
        if(header < 0){
            header = 0
        }
        datas.append(self[header ..< self.count])
        return datas
    }
    public var lengthData:Data{
        var naluLength = CFSwapInt32HostToBig(UInt32(self.count))
        return Data(bytes: &naluLength, count: 4)
    }
    
    public var blockBuffer:CMBlockBuffer?{
        
        let blockData = (self.lengthData +  self)
        let pointer = blockData.createUnsafeBuffer()
        var blockBuffer: CMBlockBuffer?
            
        let error = CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault,
                                                       memoryBlock: pointer,
                                                       blockLength: blockData.count,
                                                       blockAllocator: kCFAllocatorDefault,
                                                       customBlockSource: nil,
                                                       offsetToData: 0,
                                                       dataLength: blockData.count,
                                                       flags: .zero,
                                                       blockBufferOut: &blockBuffer)
        guard error == kCMBlockBufferNoErr else {
            print("fail to create block buffer \(error)")
            return nil
        }
        return blockBuffer
    }
    public var audioBlockBuffer:CMBlockBuffer?{

        let pointer = self.createUnsafeBuffer()
        var blockBuffer: CMBlockBuffer?
        let error = CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault,
                                                       memoryBlock: pointer,
                                                       blockLength: self.count,
                                                       blockAllocator: kCFAllocatorDefault,
                                                       customBlockSource: nil,
                                                       offsetToData: 0,
                                                       dataLength: self.count,
                                                       flags: .zero,
                                                       blockBufferOut: &blockBuffer)
        guard error == kCMBlockBufferNoErr else {
            print("fail to create block buffer \(error)")
            return nil
        }
        return blockBuffer
    }
    public func sampleBuffer(formatDescription:CMFormatDescription?,
                             size:[Int],
                             time:[CMSampleTimingInfo])->CMSampleBuffer?{
        let pointer = self.createUnsafeBuffer()
        var blockBuffer: CMBlockBuffer?
        var sampleBuffer: CMSampleBuffer?
        CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault,
                                                       memoryBlock: pointer,
                                                       blockLength: self.count,
                                                       blockAllocator: kCFAllocatorDefault,
                                                       customBlockSource: nil,
                                                       offsetToData: 0,
                                                       dataLength: self.count,
                                                       flags: .zero,
                                                       blockBufferOut: &blockBuffer)
        guard let blockBuffer else { return nil }
        CMSampleBufferCreateReady(allocator: nil, dataBuffer: blockBuffer, formatDescription: formatDescription, sampleCount: time.count, sampleTimingEntryCount: time.count, sampleTimingArray: time, sampleSizeEntryCount: size.count, sampleSizeArray: size, sampleBufferOut: &sampleBuffer)
        guard let sampleBuffer else { return nil }
        return sampleBuffer
    }
    public static func dataCutByHeaderLen(dataPointer:UnsafePointer<Int8>,
                                          totalLength:Int)->[Data]{
        var cur = 0
        var datas:[Data] = []
        while(cur < totalLength){
            
            var len:UInt32 = 0
            memcpy(&len, dataPointer + cur, 4)
            len = CFSwapInt32BigToHost(len)
            datas.append(Data(bytes: dataPointer + cur + 4, count: Int(len)))
            cur = cur + 4 + Int(len)
        }
        return datas
    }
    public func cutByHeaderLen()->[Data]{
        guard let pointer:UnsafePointer<Int8> = self.withUnsafeBytes({ p in
            return p.bindMemory(to: Int8.self)
        }).baseAddress else { return [] }
        return Data.dataCutByHeaderLen(dataPointer: pointer, totalLength: self.count)
    }
}

extension CMTime {
    public func `repeat`(count:Int)->[CMTime]{
        return (0 ..< count).map { _ in
            return self
        }
    }
}

public struct EncodeSample {
    public var sampleNalu:Data
    public var pts:CMTime
    public var dts:CMTime
    public init(sampleNalu:Data,pts:CMTime,dts:CMTime){
        self.sampleNalu = sampleNalu
        self.pts = pts
        self.dts = dts
    }
}

public enum VideoSessionPreset{
    case hd1920x1080
    case hd4K3840x2160
    case iFrame1280x720
    case iFrame960x540
    public var height:Int32{
        switch self {
            
        case .hd1920x1080:
            return 1080
        case .hd4K3840x2160:
            return 2160
        case .iFrame1280x720:
            return 720
        case .iFrame960x540:
            return 540
        }
    }
    
    public var width:Int32{
        switch self {
            
        case .hd1920x1080:
            return 1920
        case .hd4K3840x2160:
            return 3840
        case .iFrame1280x720:
            return 1280
        case .iFrame960x540:
            return 960
        }
    }
}
