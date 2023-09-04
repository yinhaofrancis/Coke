//
//  CokeCapture.swift
//  Coke
//
//  Created by wenyang on 2023/9/4.
//

import Foundation
import AVFoundation


public class CokeCapture:NSObject,AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate{

    lazy var device:AVCaptureDevice = {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera
                                                      ], mediaType: .video, position: .back).devices.first!
    }()
    lazy var microphone:AVCaptureDevice = {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInMicrophone
                                                      ], mediaType: .audio, position: .unspecified).devices.first!
    }()
    lazy var input: AVCaptureDeviceInput = {
        return try! AVCaptureDeviceInput(device: self.device)
    }()
    lazy var microPhone: AVCaptureDeviceInput = {
        return try! AVCaptureDeviceInput(device: self.microphone)
    }()
    lazy var output: AVCaptureVideoDataOutput = {
        let out =  AVCaptureVideoDataOutput()
        out.videoSettings = [kCVPixelBufferPixelFormatTypeKey as! String: kCVPixelFormatType_32BGRA]
        out.setSampleBufferDelegate(self, queue: .global())
        return out
    }()
    lazy var audioOutput : AVCaptureAudioDataOutput = {
        let out = AVCaptureAudioDataOutput()
        out.setSampleBufferDelegate(self, queue: .global())
        return out
    }()
    lazy var session: AVCaptureSession = {
        return AVCaptureSession()
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
        
        self.session.addInput(self.microPhone)
        self.session.addInput(self.input)
        self.session.addOutput(self.output)
        self.session.addOutput(self.audioOutput)
        self.session.sessionPreset = self.preset
        
    }
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if(self.quickDisplay){
            sampleBuffer.setDisplayImmediately(di: true)
        }
        self.callback(sampleBuffer)
    }

    
    public func start(){
        DispatchQueue.global().async {
            self.session.startRunning()
        }
    }
    public func stop(){
        DispatchQueue.global().async {
            self.session.stopRunning()
        }
    }
}

