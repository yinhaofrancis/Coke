//
//  CokeCapture.swift
//  Coke
//
//  Created by wenyang on 2023/9/4.
//

import Foundation
import AVFoundation


public class CokeCapture:NSObject,
                         AVCaptureVideoDataOutputSampleBufferDelegate,
                         CokeAudioRecoderOutput{
    public func handle(recorder: CokeAudioRecorder, output: CokeAudioOutputBuffer) {
        guard let accbudder =  self.aacEncode?.encode(buffer: output)?.createSampleBuffer() else { return }
        self.callback(accbudder)
        
    }
    

    lazy var device:AVCaptureDevice = {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera
                                                      ], mediaType: .video, position: .back).devices.first!
    }()

    lazy var input: AVCaptureDeviceInput = {
        return try! AVCaptureDeviceInput(device: self.device)
    }()

    lazy var output: AVCaptureVideoDataOutput = {
        let out =  AVCaptureVideoDataOutput()
        out.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        out.setSampleBufferDelegate(self, queue: .global())
        return out
    }()

    lazy var session: AVCaptureSession = {
        return AVCaptureSession()
    }()

    lazy var record:CokeAudioRecorder = {
        let c = try!CokeAudioRecorder()
        c.output = self
        return c
    }()
    lazy var aacEncode:CokeAudioConverterAAC? = {
        CokeAudioConverterAAC(encode: record.audioStreamBasicDescription)
    }()
    
    var callback:(CMSampleBuffer)->Void
    public var preset:AVCaptureSession.Preset
    public init(preset:AVCaptureSession.Preset = .iFrame1280x720,callback:@escaping (CMSampleBuffer)->Void){
        self.callback = callback
        self.preset = preset
        super.init()
        if AVCaptureDevice.authorizationStatus(for: .video) == .authorized{
            self.loadConfig()
        }else{
            AVCaptureDevice.requestAccess(for: .video) { b in
                self.loadConfig()
            }
        }
    
    }
    public var quickDisplay:Bool = false;
    public func loadConfig(){
        
        self.session.addInput(self.input)
        self.session.addOutput(self.output)
        self.session.sessionPreset = self.preset
        guard let connect = self.output.connection(with: .video) else { return }
        if connect.isVideoOrientationSupported{
            connect.videoOrientation = .portrait
        }
        
    }
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if(self.quickDisplay){
            sampleBuffer.setDisplayImmediately(di: true)
        }
        self.callback(sampleBuffer)
    }

    
    public func start(){
        DispatchQueue.global().async {
            try! AVAudioSession.sharedInstance().setCategory(.record)
            self.session.startRunning()
            self.aacEncode?.reset()
            self.record.start()
        }
    }
    public func stop(){
        DispatchQueue.global().async {
            self.session.stopRunning()
            self.record.stop()
        }
    }
}

