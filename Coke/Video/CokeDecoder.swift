//
//  CokeDecoder.swift
//  Coke
//
//  Created by hao yin on 2022/1/12.
//

import AVFoundation
import VideoToolbox

public protocol VideoDecoderConfiguration{
    func config(tool:VTDecompressionSession,ve:VideoDecoder)
    func formatDescription(sample:CMSampleBuffer)->CMVideoFormatDescription
}
public class VideoDecoder:VideoOutputData{
    public func outputVideoFrame(frame: CMSampleBuffer) {
        self.encode(sample: frame)
    }
    var config:VideoDecoderConfiguration
    var session:VTDecompressionSession?
    var umSelf:Unmanaged<VideoDecoder>?
    var callback:VTDecompressionOutputCallbackRecord?
    public weak var dataOut:VideoOutputData?
    public init(config:VideoDecoderConfiguration){
        self.config = config
    }

    func createSession(sample:CMSampleBuffer) throws {
        if umSelf == nil{
            self.umSelf = Unmanaged.passRetained(self)
        }
        guard let ws = self.umSelf else { throw NSError(domain: "VideoEncoder is not ready", code: 0, userInfo: nil) }
        self.callback = VTDecompressionOutputCallbackRecord(decompressionOutputCallback: { decompression, frame, status, flag, buffers, present, during in
            guard let wselfp = decompression else { return }
            let w = Unmanaged<VideoDecoder>.fromOpaque(wselfp).takeUnretainedValue()
            guard let buff = buffers  else { return }
            w.handle(buffers: buff, present: present, during: during)
            
        }, decompressionOutputRefCon: ws.toOpaque())
        let status = VTDecompressionSessionCreate(allocator: nil, formatDescription: self.config.formatDescription(sample: sample), decoderSpecification: nil, imageBufferAttributes: nil, outputCallback: &(self.callback!), decompressionSessionOut: &self.session)
        if status != noErr{
            throw NSError(domain: "decompress error \(status)", code: 0, userInfo: nil)
        }
    }
    func finalSession(){
        guard let ses = self.session else { return  }
        VTDecompressionSessionFinishDelayedFrames(ses)
        self.umSelf?.release()
        self.umSelf = nil
        self.session = nil
    }
    public func encode(sample:CMSampleBuffer){
        do{
            try self.createSession(sample: sample)
        }catch{
            
        }
        guard let ses = self.session else { return }
        var flag = VTDecodeInfoFlags.asynchronous
        VTDecompressionSessionDecodeFrame(ses, sampleBuffer: sample, flags: VTDecodeFrameFlags._EnableAsynchronousDecompression, infoFlagsOut: &flag) { status, flag, buffer, present, during in
            guard let buff = buffer else { return }
            self.handle(buffers: buff, present: present, during: during)
        }
    }
    func handle(buffers:CVImageBuffer,present:CMTime,during:CMTime){
        var format:CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: buffers, formatDescriptionOut: &format)
        guard let rformat = format else { return }
        var time = CMSampleTimingInfo.invalid
        var sample:CMSampleBuffer?
        let out = CMSampleBufferCreateForImageBuffer(allocator: nil, imageBuffer: buffers, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: rformat, sampleTiming: &time, sampleBufferOut: &sample)
        if out == noErr {
            self.dataOut?.outputVideoFrame(frame: sample!)
        }
    }
    
}
