//
//  CodeVideoDecode.swift
//  Coke
//
//  Created by wenyang on 2023/9/5.
//

import Foundation
import VideoToolbox

public typealias VideoEncoderHandleCallback = (VTDecodeInfoFlags,CMSampleBuffer?)->Void

public class VideoEncoderHandle{
    public var callback:VideoEncoderHandleCallback
    init(callback: @escaping VideoEncoderHandleCallback) {
        self.callback = callback
    }
    public func createSampleBuffer(flag:VTDecodeInfoFlags,
                                   imageBuffer:CVImageBuffer?,
                                   timestamp:CMTime,
                                   during:CMTime){
        guard let imageBuffer else { return }
        var videoDescription:CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: imageBuffer, formatDescriptionOut: &videoDescription)
        var sample:CMSampleBuffer?
        
        var time = CMSampleTimingInfo(duration: during, presentationTimeStamp: timestamp, decodeTimeStamp: .invalid)
        CMSampleBufferCreateForImageBuffer(allocator: nil, imageBuffer: imageBuffer, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: videoDescription!, sampleTiming: &time, sampleBufferOut: &sample)
        callback(flag,sample)
    
    }
}

public class CokeVideoDecode{
    
    public var session:VTDecompressionSession?
    public var callback:VTDecompressionOutputCallbackRecord?
    public var handle:VideoEncoderHandle
    public var videoDescription:CMVideoFormatDescription?
    public var pixelFormat:OSType
    public init(pixelFormat:OSType = kCVPixelFormatType_420YpCbCr8Planar,callback:@escaping VideoEncoderHandleCallback) {
        self.handle = VideoEncoderHandle(callback: callback)
        self.pixelFormat = pixelFormat
    }

    public func config(videoDescription:CMVideoFormatDescription) throws{
        
        if let _session = self.session{
            DispatchQueue.global().async {
                VTDecompressionSessionWaitForAsynchronousFrames(_session)
                VTDecompressionSessionInvalidate(_session)
            }
        }
        self.session = nil
        let dic:CFDictionary = [kCVPixelBufferPixelFormatTypeKey:pixelFormat as CFNumber] as CFDictionary
        var decompress:VTDecompressionSession?
        
        var callback = VTDecompressionOutputCallbackRecord(
            decompressionOutputCallback: { decompressionOutputRefCon, sourceFrameRefCon, status, flag, imageBuffer, timestamp, during in
                guard let handlePtr = decompressionOutputRefCon else { return }
                let handleEncode  = Unmanaged<VideoEncoderHandle>.fromOpaque(handlePtr).takeUnretainedValue()
                handleEncode.createSampleBuffer(flag:flag, imageBuffer: imageBuffer, timestamp:timestamp, during: during)
        }, decompressionOutputRefCon: Unmanaged<VideoEncoderHandle>.passUnretained(handle).toOpaque())
        VTDecompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            formatDescription: videoDescription,
            decoderSpecification: nil,
            imageBufferAttributes: dic,
            outputCallback: &callback,
            decompressionSessionOut: &decompress)
        guard let decompress else { throw NSError(domain: "create decompress fail", code: 0)}
        self.callback = callback
        self.session = decompress
        self.videoDescription = videoDescription
        if !(VTDecompressionSessionCanAcceptFormatDescription(self.session!, formatDescription: videoDescription)){
            throw NSError(domain: "decode is no work ", code: 0)
        }
    }
    public func decode(sampleBuffer:CMSampleBuffer){
        if(sampleBuffer.isIFrame || self.videoDescription == nil){
            do{
                guard let format = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
                try self.config(videoDescription: format)
            }catch{
                print(error)
                return
            }
            
        }
        guard let session = self.session else { return }
        let e = VTDecompressionSessionDecodeFrame(session, sampleBuffer: sampleBuffer, flags: ._EnableAsynchronousDecompression, frameRefcon: nil, infoFlagsOut: nil)
        if (e == noErr){
            return
        }
    }
}


extension CokeVideoDecode{
    public static func videoDescriptionFromH264(params:[Data]) -> CMVideoFormatDescription?{
        var result:CMVideoFormatDescription?
        let paramMPointer = params.map { $0.createUnsafeBuffer() }
        let paramPointer = paramMPointer.map({UnsafePointer($0)})
        let parameterSetSizes = params.map{$0.count}
        CMVideoFormatDescriptionCreateFromH264ParameterSets(allocator: kCFAllocatorDefault, parameterSetCount: params.count, parameterSetPointers: paramPointer, parameterSetSizes: parameterSetSizes, nalUnitHeaderLength: 4, formatDescriptionOut: &result)
        paramMPointer.forEach { i in
            i.deallocate()
        }
        return result
    }
    
    public static func videoDescriptionFromHEVC(params:[Data]) -> CMVideoFormatDescription?{
        var result:CMVideoFormatDescription?
        let paramMPointer = params.map { $0.createUnsafeBuffer() }
        let paramPointer = paramMPointer.map({UnsafePointer($0)})
        let parameterSetSizes = params.map{$0.count}
        CMVideoFormatDescriptionCreateFromHEVCParameterSets(allocator: nil, parameterSetCount: params.count, parameterSetPointers: paramPointer, parameterSetSizes: parameterSetSizes, nalUnitHeaderLength: 4, extensions: nil, formatDescriptionOut: &result)
        paramMPointer.forEach { i in
            i.deallocate()
        }
        return result
    }
}

