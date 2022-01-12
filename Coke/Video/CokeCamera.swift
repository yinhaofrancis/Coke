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



