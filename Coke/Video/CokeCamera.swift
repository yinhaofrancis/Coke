//
//  Camera.swift
//  Render
//
//  Created by hao yin on 2022/1/10.
//

import AVFoundation
import VideoToolbox

public class CokeCamera:NSObject,AVCaptureVideoDataOutputSampleBufferDelegate{
    private var device:AVCaptureDevice
    private var input:AVCaptureDeviceInput
    private var output:AVCaptureVideoDataOutput
    private var session:AVCaptureSession
    
    public unowned var dataOut:VideoOutputData
    
    public init(dataOut:VideoOutputData) throws{

        if #available(iOS 13.0, *) {
            guard let device = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) else {
                throw NSError(domain: "create device error", code: 0, userInfo: nil)
            }
            self.device = device
        } else {
            // Fallback on earlier versions
            guard let device = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back) else {
                throw NSError(domain: "create device error", code: 0, userInfo: nil)
            }
            self.device = device
        }
        
        self.input = try AVCaptureDeviceInput(device: device)
        self.output = AVCaptureVideoDataOutput()
        self.session = AVCaptureSession()
        self.dataOut = dataOut
        super.init()
    }
    public var sessionPreset: AVCaptureSession.Preset = .high{
        didSet{
            self.session.beginConfiguration()
            self.session.sessionPreset = self.sessionPreset
            self.session.commitConfiguration()
        }
    }
    private var frameRate:CMTimeScale = 24
    public func start(){
        try! self.device.lockForConfiguration()
        self.device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: self.frameRate)
        self.device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: self.frameRate)
        self.device.unlockForConfiguration()
        self.session.beginConfiguration()
        self.session.sessionPreset = self.sessionPreset
        if self.session.canAddInput(self.input){
            self.session.addInput(self.input)
        }
        self.output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_422YpCbCr8]
        if self.session.canAddOutput(self.output){
            self.session.addOutput(self.output)
            self.output.connection(with: .video)?.videoOrientation = .portrait
        }
        
        self.output.setSampleBufferDelegate(self, queue: DispatchQueue.global())
        self.session.commitConfiguration()
        self.session.startRunning()
    }
    public func stop(){
        self.session.stopRunning()
    }
    public static func registerPermision(callback:@escaping (Bool)->Void){
        switch(self.permission){
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video, completionHandler: callback)
            break
        case .restricted:
            AVCaptureDevice.requestAccess(for: .video, completionHandler: callback)
            break
        default:
            callback(self.permission == .authorized)
            break
        }
    }
    
    public static var permission:AVAuthorizationStatus{
        AVCaptureDevice.authorizationStatus(for: .video)
    }
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        self.dataOut.outputVideoFrame(frame: sampleBuffer)
    }
}

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
    }
}
public struct HevcConfiguration:VideoEncoderConfiguration{

    public var codec: CMVideoCodecType = kCMVideoCodecType_HEVCWithAlpha
    
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
    }
}
public class VideoWriter:VideoOutputData{
    public func outputVideoFrame(frame: CMSampleBuffer) {
        while !self.input.isReadyForMoreMediaData {
            
        }
        self.input.requestMediaDataWhenReady(on: .global()) {
            self.input.append(frame)
        }
    }

    public var write:AVAssetWriter
    
    public var input:AVAssetWriterInput
    
    public init(url:URL,type:AVFileType = .mp4) throws {
        try? FileManager.default.removeItem(at: url)
        FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil)
        self.write = try AVAssetWriter(url: url, fileType: type)
        self.input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey : AVVideoCodecType.h264,
            AVVideoHeightKey:720,
            AVVideoWidthKey:1280
        ])
        self.write.add(self.input)
    }

    public func close(){
        self.input.markAsFinished()
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
