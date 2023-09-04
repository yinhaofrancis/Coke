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

public class CodeVideoEncode{
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
    public var bframe:Bool{
        get{
            let b = kCFBooleanFalse!
            
            VTSessionCopyProperty(self, key: kVTCompressionPropertyKey_AllowFrameReordering, allocator: nil, valueOut: Unmanaged.passUnretained(b).toOpaque())
            
            return CFBooleanGetValue(b)
        }
        set{
            VTSessionSetProperty(self.session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: newValue ? kCFBooleanTrue : kCFBooleanFalse)
        }
    }
    public var maxKeyFrameInterval:Int{
        get{
            var int32 = 0
            let b = CFNumberCreate(kCFAllocatorDefault, .sInt32Type, &int32)
            
            VTSessionCopyProperty(self, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, allocator: nil, valueOut: Unmanaged.passUnretained(b!).toOpaque())
            
            CFNumberGetValue(b, .sInt32Type, &int32)
            return int32
        }
        set{
            var int32 = 0
            let b = CFNumberCreate(kCFAllocatorDefault, .sInt32Type, &int32)
            VTSessionSetProperty(self.session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: b)
        }
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
