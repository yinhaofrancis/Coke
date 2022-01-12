//
//  CokeEncoder.swift
//  Coke
//
//  Created by hao yin on 2022/1/12.
//

import AVFoundation
import VideoToolbox

public protocol VideoOutputData:AnyObject{
    func outputVideoFrame(frame:CMSampleBuffer)
}
public protocol VideoEncoderConfiguration{
    func config(tool:VTCompressionSession,ve:VideoEncoder)
    var codec:CMVideoCodecType { get }
}


public struct H264Configuration:VideoEncoderConfiguration{

    public var codec: CMVideoCodecType = kCMVideoCodecType_H264
    
    public func config(tool: VTCompressionSession,ve:VideoEncoder) {
        VTSessionSetProperty(tool, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue);
        VTSessionSetProperty(tool, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Baseline_AutoLevel);
        var f:Int32 = 30
        VTSessionSetProperty(tool, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: CFNumberCreate(nil, .sInt32Type, &f))
        
        VTSessionSetProperty(tool, key: kVTCompressionPropertyKey_ExpectedFrameRate,  value: CFNumberCreate(nil, .intType, &f));
        var btr:Int32 = ve.w * ve.h * 3 * 4 * 8
        VTSessionSetProperty(tool, key: kVTCompressionPropertyKey_AverageBitRate, value: CFNumberCreate(nil, .sInt32Type, &btr))
        
        var bitRateLimit:Int32 = ve.w * ve.h * 3 * 4;
        VTSessionSetProperty(tool, key:kVTCompressionPropertyKey_DataRateLimits, value:CFNumberCreate(kCFAllocatorDefault, .sInt32Type, &bitRateLimit));
        var qulity:Float = 0.25
        VTSessionSetProperty(tool, key: kVTCompressionPropertyKey_Quality, value: CFNumberCreate(kCFAllocatorDefault, .floatType, &qulity));
    }
}
public struct JpegConfiguration:VideoEncoderConfiguration{

    public var codec: CMVideoCodecType = kCMVideoCodecType_JPEG
    
    public func config(tool: VTCompressionSession,ve:VideoEncoder) {
        VTSessionSetProperty(tool, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue);
        var f:Int32 = 30
        VTSessionSetProperty(tool, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: CFNumberCreate(nil, .sInt32Type, &f))
        
        VTSessionSetProperty(tool, key: kVTCompressionPropertyKey_ExpectedFrameRate,  value: CFNumberCreate(nil, .intType, &f));
        var btr:Int32 = ve.w * ve.h * 3 * 4 * 8
        VTSessionSetProperty(tool, key: kVTCompressionPropertyKey_AverageBitRate, value: CFNumberCreate(nil, .sInt32Type, &btr))
        
        var bitRateLimit:Int32 = ve.w * ve.h * 3 * 4;
        VTSessionSetProperty(tool, key:kVTCompressionPropertyKey_DataRateLimits, value:CFNumberCreate(kCFAllocatorDefault, .sInt32Type, &bitRateLimit));
        var qulity:Float = 0.25
        VTSessionSetProperty(tool, key: kVTCompressionPropertyKey_Quality, value: CFNumberCreate(kCFAllocatorDefault, .floatType, &qulity));
    }
}
public struct HevcConfiguration:VideoEncoderConfiguration{

    public var codec: CMVideoCodecType = kCMVideoCodecType_HEVC
    
    public func config(tool: VTCompressionSession,ve:VideoEncoder) {
        VTSessionSetProperty(tool, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue);
        VTSessionSetProperty(tool, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_HEVC_Main_AutoLevel);
        var f:Int32 = 30
        VTSessionSetProperty(tool, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: CFNumberCreate(nil, .sInt32Type, &f))
        
        VTSessionSetProperty(tool, key: kVTCompressionPropertyKey_ExpectedFrameRate,  value: CFNumberCreate(nil, .intType, &f));
        var btr:Int32 = ve.w * ve.h * 3 * 4 * 8
        VTSessionSetProperty(tool, key: kVTCompressionPropertyKey_AverageBitRate, value: CFNumberCreate(nil, .sInt32Type, &btr))
        
        var bitRateLimit:Int32 = ve.w * ve.h * 3 * 4;
        VTSessionSetProperty(tool, key:kVTCompressionPropertyKey_DataRateLimits, value:CFNumberCreate(kCFAllocatorDefault, .sInt32Type, &bitRateLimit));
        var qulity:Float = 0.25
        VTSessionSetProperty(tool, key: kVTCompressionPropertyKey_Quality, value: CFNumberCreate(kCFAllocatorDefault, .floatType, &qulity));
    }
}

public class VideoEncoder:VideoOutputData{
    public func outputVideoFrame(frame: CMSampleBuffer) {
        guard let buffer = CMSampleBufferGetImageBuffer(frame) else { return }
        self.encode(buffer: buffer, presentationTimeStamp: CMSampleBufferGetPresentationTimeStamp(frame), during: CMSampleBufferGetDuration(frame))
    }
    
    public private(set) var w:Int32
    public private(set) var h:Int32
    var session:VTCompressionSession?
    var config:VideoEncoderConfiguration
    var umSelf:Unmanaged<VideoEncoder>?
    public weak var dataOut:VideoOutputData?
    public init(configuration:VideoEncoderConfiguration? = nil)throws {
        self.w = 1
        self.h = 1
        self.config = configuration ?? JpegConfiguration()
        try self.start()
    }
    func start() throws{
        if umSelf == nil{
            self.umSelf = Unmanaged.passRetained(self)
        }
        
        guard let ws = self.umSelf else { throw NSError(domain: "VideoEncoder is not ready", code: 0, userInfo: nil) }
        let status = VTCompressionSessionCreate(allocator: nil, width: self.w, height: self.h, codecType: self.config.codec, encoderSpecification: nil, imageBufferAttributes: nil, compressedDataAllocator: nil, outputCallback: { out, frame, status, flag, buffer in
            guard let buff = buffer else { return }
            guard let o = out else { return }
            Unmanaged<VideoEncoder>.fromOpaque(o).takeUnretainedValue().dataOut?.outputVideoFrame(frame: buff)
        }, refcon: ws.toOpaque(), compressionSessionOut: &self.session)
        if status != noErr{
            self.umSelf?.release()
            self.umSelf = nil
            throw NSError(domain: "create session Error errcode \(status)", code: Int(status), userInfo: nil)
        }
        guard let session = self.session else { throw NSError(domain: "create session Error errcode \(status)", code: Int(status), userInfo: nil) }
        self.config.config(tool: session,ve: self)
        
        VTCompressionSessionPrepareToEncodeFrames(session)
    }
    public func stop(){
        self.umSelf?.release()
        self.umSelf = nil
        guard let session = session else {
            return
        }

        VTCompressionSessionInvalidate(session)
        VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
    }
    public func encode(buffer:CVPixelBuffer,presentationTimeStamp:CMTime,during:CMTime){
        guard let ses = self.session else { return }
        guard let ws = self.umSelf else { return }
        if CVPixelBufferGetWidth(buffer) - Int(self.w) != 0 ||
            CVPixelBufferGetHeight(buffer) - Int(self.h) != 0{
            self.w = Int32(CVPixelBufferGetWidth(buffer))
            self.h = Int32(CVPixelBufferGetHeight(buffer))
            do{
                try self.start()
            }catch{
                return
            }
        }
        var flag:VTEncodeInfoFlags = VTEncodeInfoFlags.frameDropped
        VTCompressionSessionEncodeFrame(ses, imageBuffer: buffer, presentationTimeStamp: presentationTimeStamp, duration: during, frameProperties: nil, sourceFrameRefcon: ws.toOpaque(), infoFlagsOut: &flag)
    }
}
