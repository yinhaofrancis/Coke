//
//  File.swift
//  Coke
//
//  Created by wenyang on 2023/9/4.
//

import VideoToolbox

public struct VideoEncoderBuffer{
    public var imagebuffer:CVImageBuffer
    public var presentationTimeStamp:CMTime
    public var duration:CMTime
    public init(imagebuffer: CVImageBuffer, presentationTimeStamp: CMTime, duration: CMTime = .invalid) {
        self.imagebuffer = imagebuffer
        self.presentationTimeStamp = presentationTimeStamp
        self.duration = duration
    }
    public init?(sample:CMSampleBuffer){
        if(sample.mediaType != kCMMediaType_Video){
            return nil
        }
        guard let img = CMSampleBufferGetImageBuffer(sample) else { return nil }
        let pt = CMSampleBufferGetPresentationTimeStamp(sample)
        let during = CMSampleBufferGetDuration(sample)
        self.init(imagebuffer: img, presentationTimeStamp: pt, duration: during)
    }
}


public typealias ImageCallback = (OSStatus,VTEncodeInfoFlags,CMSampleBuffer?,Int)->Void

public class CodeVideoEncoder{
    public var session:VTCompressionSession
    
    public init(width:Int32,
                height:Int32,
                pixelFormat:OSType = kCVPixelFormatType_420YpCbCr8Planar,
                codec:CMVideoCodecType = kCMVideoCodecType_H264,
                propertys:CFDictionary? = nil) throws{
        let dic:CFDictionary = [kCVPixelBufferPixelFormatTypeKey:pixelFormat as CFNumber] as CFDictionary
        var ses:VTCompressionSession?
        let ret = VTCompressionSessionCreate(allocator: kCFAllocatorDefault,
                                   width: width,
                                   height: height,
                                   codecType: codec,
                                   encoderSpecification: nil,
                                   imageBufferAttributes: dic,
                                   compressedDataAllocator: nil,
                                   outputCallback: nil,
                                   refcon: nil,
                                   compressionSessionOut: &ses)
       
        if ses == nil {
            throw NSError(domain: "create encoder fail \(ret)", code: Int(ret))
        }
        if let propertys,let ses{
            VTSessionSetProperties(ses, propertyDictionary: propertys)
        }
        self.session = ses!
        if VTCompressionSessionPrepareToEncodeFrames(session) != noErr{
            throw NSError(domain: "create encoder fail \(ret)", code: Int(ret))
        }
    }
    public func setBframe(bframe:Bool){
        VTSessionSetProperty(self.session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: bframe ? kCFBooleanTrue : kCFBooleanFalse)
    }
    public func setMaxKeyFrameInterval(maxKeyFrameInterval:Int){
        var int32 = maxKeyFrameInterval
        let b = CFNumberCreate(kCFAllocatorDefault, .sInt32Type, &int32)
        VTSessionSetProperty(self.session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: b)
    }
    public func setAverageBitRate(averageBitRate:Int32){
        var int32 = averageBitRate
        let b = CFNumberCreate(kCFAllocatorDefault, .sInt32Type, &int32)
        VTSessionSetProperty(self.session, key: kVTCompressionPropertyKey_AverageBitRate, value: b)
    }
    @available(iOS 16.0, *)
    public func setConstantBitRate(cbr:Int32){
        var int32 = cbr
        let b = CFNumberCreate(kCFAllocatorDefault, .sInt32Type, &int32)
        VTSessionSetProperty(self.session, key: kVTCompressionPropertyKey_ConstantBitRate, value: b)
    }
    @available(iOS 15.0, *)
    public func setMaxAllowQP(qp:Float){
        var qp = qp
        let b = CFNumberCreate(kCFAllocatorDefault, .floatType, &qp)
        VTSessionSetProperty(self.session, key: kVTCompressionPropertyKey_MaxAllowedFrameQP, value: b)
    }
    @available(iOS 16.0, *)
    public func setMinAllowQP(qp:Float){
        var qp = qp
        let b = CFNumberCreate(kCFAllocatorDefault, .floatType, &qp)
        VTSessionSetProperty(self.session, key: kVTCompressionPropertyKey_MinAllowedFrameQP, value: b)
    }
    
    public func setQuality(quality:Float){
        var float = quality
        let b = CFNumberCreate(kCFAllocatorDefault, .floatType, &float)
        VTSessionSetProperty(self.session, key: kVTCompressionPropertyKey_Quality, value: b)
    }
    
    public func setFrameRate(frameRate:Int32){
        var int32 = frameRate
        let b = CFNumberCreate(kCFAllocatorDefault, .sInt32Type, &int32)
        VTSessionSetProperty(self.session, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: b)
    }
    
    public func setProfileLevel(value:CFString){
        VTSessionSetProperty(self.session, key: kVTCompressionPropertyKey_ProfileLevel, value: value)
    }
    
    public func encode(buffer:VideoEncoderBuffer,callback:@escaping ImageCallback){
        let currentBuffer = buffer
        let err = VTCompressionSessionEncodeFrame(self.session, imageBuffer: currentBuffer.imagebuffer, presentationTimeStamp: currentBuffer.presentationTimeStamp, duration: currentBuffer.duration, frameProperties: nil, infoFlagsOut: nil) { ret, flag, buffer in
            callback(ret,flag,buffer,0)
        }
        guard err == noErr else {
            VTCompressionSessionPrepareToEncodeFrames(self.session)
            print("(\(err))")
            return
        }
    }
    public func complete(untilPresentationTimeStamp:CMTime = .invalid){
        VTCompressionSessionCompleteFrames(self.session, untilPresentationTimeStamp: untilPresentationTimeStamp)
    }
    public lazy  var pixelBufferPool:CVPixelBufferPool? = {
        VTCompressionSessionGetPixelBufferPool(self.session)
    }()

    deinit{
        VTCompressionSessionInvalidate(self.session)
    }
}
