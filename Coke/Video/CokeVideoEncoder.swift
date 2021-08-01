//
//  VideoEncoder.swift
//  Coke
//
//  Created by hao yin on 2021/5/8.
//

import Foundation
import VideoToolbox
import AVFoundation
public class CokeVideoEncoder{

    public func handleBuffer(sampleBuffer: CMSampleBuffer) {
        self.encode(buffer: sampleBuffer)
    }
    
    private var session:VTCompressionSession?
    
    private var callback:((Data?)->Void)?
    public init(width:Int32,height:Int32,quality:Float = 0.25) throws {
        let err = VTCompressionSessionCreate(allocator: nil, width: width, height: height, codecType: kCMVideoCodecType_H264, encoderSpecification: nil, imageBufferAttributes: nil, compressedDataAllocator: nil, outputCallback: { outputCallbackRefCon, sourceFrameRefCon, status, infoFlags, sampleBuffer in
            let e = outputCallbackRefCon?.assumingMemoryBound(to: CokeVideoEncoder.self).pointee
            e?.callback(sourceFrameRefCon: sourceFrameRefCon, status: status, infoFlags: infoFlags, sampleBuffer: sampleBuffer)
        }, refcon: Unmanaged.passUnretained(self).toOpaque(), compressionSessionOut: &self.session)
        
        if err == errSecSuccess{
            guard let sess = self.session else { throw NSError(domain: "compress Session", code: 0, userInfo: nil) }
            let bitRate = width * height * 3 * 4 * 8
            let frameInterval:Int32 = 60
            let limti = [Double(bitRate) * 1.5 / 8, 1]
            VTSessionSetProperties(sess, propertyDictionary: [
                kVTCompressionPropertyKey_ProfileLevel:kVTProfileLevel_H264_Baseline_AutoLevel,
                kVTCompressionPropertyKey_AverageBitRate:bitRate,
                kVTCompressionPropertyKey_MaxKeyFrameInterval:frameInterval,
                kVTCompressionPropertyKey_DataRateLimits: limti,
                kVTCompressionPropertyKey_RealTime:true,
                kVTCompressionPropertyKey_Quality:quality,
            ] as CFDictionary)
            VTCompressionSessionPrepareToEncodeFrames(sess)
        }else{
            throw NSError(domain: "compress Session", code: 0, userInfo: nil)
        }
        
        
    }
    public func callback(sourceFrameRefCon:UnsafeMutableRawPointer?, status:OSStatus, infoFlags:VTEncodeInfoFlags, sampleBuffer:CMSampleBuffer?){
        guard let buffer = sampleBuffer else { return }
        if CMSampleBufferDataIsReady(buffer) {
            guard let array = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: true) as? Array<Dictionary<CFString,Any>> else { return }
            if (array[0][kCMSampleAttachmentKey_NotSync] != nil){
                guard let format = CMSampleBufferGetFormatDescription(buffer) else { return }
                var sparameterSetSize = 0
                var sparameterSetCount = 0
                var sparameterSet:UnsafePointer<UInt8>?

                CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, parameterSetIndex: 0, parameterSetPointerOut: &sparameterSet, parameterSetSizeOut: &sparameterSetSize, parameterSetCountOut: &sparameterSetCount, nalUnitHeaderLengthOut: nil)
               
                var spsdata = Data()
                spsdata.append(contentsOf: [0,0,0,1])
                spsdata.append(Data(bytes: sparameterSet!, count: sparameterSetSize))
                self.callback?(spsdata)
                
                var pparameterSetSize = 0
                var pparameterSetCount = 0
                var pparameterSet:UnsafePointer<UInt8>?

                CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, parameterSetIndex: 1, parameterSetPointerOut: &pparameterSet, parameterSetSizeOut: &pparameterSetSize, parameterSetCountOut: &pparameterSetCount, nalUnitHeaderLengthOut: nil)
                var ppsdata = Data()
                ppsdata.append(contentsOf: [0,0,0,1])
                ppsdata.append(Data(bytes: pparameterSet!, count: pparameterSetSize))
                self.callback?(ppsdata)
            }
            guard let block = CMSampleBufferGetDataBuffer(buffer) else { return }
            var length = 0
            var totalLength = 0
            var datap:UnsafeMutablePointer<CChar>?
            let statusCodeRet = CMBlockBufferGetDataPointer(block, atOffset: 0, lengthAtOffsetOut: &length, totalLengthOut: &totalLength, dataPointerOut: &datap)
            if statusCodeRet == errSecSuccess{
                var offset = 0
                var nalunitLength = 0
                while offset < totalLength - AVCCHeaderLength {
                    
                    memcpy(&nalunitLength, datap?.advanced(by: offset), AVCCHeaderLength)
                    
                    nalunitLength = Int(CFSwapInt32BigToHost(UInt32(nalunitLength)))
                    var nuadata = Data()
                    nuadata.append(contentsOf: [0,0,0,1])
                    let data = Data(bytes: datap!.advanced(by: offset + AVCCHeaderLength), count: nalunitLength)
                    nuadata.append(data)
                    self.callback?(nuadata)
                    offset += AVCCHeaderLength + nalunitLength
                }
            }
        }
    }
    public let AVCCHeaderLength = 4
    public func setCallback(callback:@escaping (Data?)->Void){
        self.callback = callback
    }
    public func encode(buffer:CMSampleBuffer){
        guard let session = self.session else { return }
        guard let px = CMSampleBufferGetImageBuffer(buffer) else { return }
        let time = CMSampleBufferGetPresentationTimeStamp(buffer)

        var flag:VTEncodeInfoFlags = VTEncodeInfoFlags()
        VTCompressionSessionEncodeFrame(session, imageBuffer: px, presentationTimeStamp: time, duration: time, frameProperties: nil, sourceFrameRefcon: nil, infoFlagsOut: &flag)
    }
    deinit {
        if let sess = session{
            VTCompressionSessionInvalidate(sess)
        }
    }
}
