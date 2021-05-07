//
//  CokeCamera.swift
//  Coke
//
//  Created by hao yin on 2021/5/7.
//

import AVFoundation
import UIKit

public class CokeCamera:NSObject,AVCapturePhotoCaptureDelegate{
    
    public typealias CallbackBlock = (UIImage?)->Void
    public struct Exposure{
        public var iso:Float
        public var during:TimeInterval
        public init(iso:Float,during:TimeInterval){
            self.iso = iso
            self.during = during
        }
    }
    private var callback:CallbackBlock?
    
    public var camera:[AVCaptureDevice] = []
    
    public var session:AVCaptureSession
    public var videoOutput:AVCaptureVideoDataOutput = AVCaptureVideoDataOutput()
    public var photoOut = AVCapturePhotoOutput()
    public var position:AVCaptureDevice.Position{
        didSet{
            self.loadCamera()
            self.startCapture()
        }
    }
    public override init(){
        self.session = AVCaptureSession()
        self.session.addOutput(self.videoOutput)
        self.session.addOutput(self.photoOut)
        self.videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String :kCVPixelFormatType_32BGRA]
        
        self.position = .back
        
        super.init()
        self.loadCamera()
    }
    
    public func loadCamera(){
        self.camera = CokeCamera.devices(position: self.position)
        self.cameraInput = self.camera.map { c in
            do{
                return try AVCaptureDeviceInput(device: c)
            }catch{
                return nil
            }
            
        }.compactMap({$0})
    }
    public static var videoAccess:AVAuthorizationStatus{
        AVCaptureDevice.authorizationStatus(for: .video)
    }
    public class func request(call: @escaping (Bool)->Void){
  
        
        if(self.videoAccess == .authorized){
            call(true)
        }else if self.videoAccess == .denied{
            call(false)
        }else {
            AVCaptureDevice.requestAccess(for: .video) { b in
                DispatchQueue.main.async {
                    call(b)
                }
            }
        }
    }
    
    public static func devices(position:AVCaptureDevice.Position)->[AVCaptureDevice]{
        let session = AVCaptureDevice.DiscoverySession(deviceTypes: self.types, mediaType: .video, position: position)
        return session.devices
    }
    
    public static var types:[AVCaptureDevice.DeviceType]{
        if #available(iOS 13.0, *) {
            return [.builtInDualCamera,
                    .builtInDualWideCamera,
                    .builtInTelephotoCamera,
                    .builtInTripleCamera,
                    .builtInTrueDepthCamera,
                    .builtInUltraWideCamera,
                    .builtInWideAngleCamera]
        } else {
            return [.builtInDualCamera,
                    .builtInTelephotoCamera,
                    .builtInTrueDepthCamera,
                    .builtInWideAngleCamera]
        }
    }
    public func startCapture(){
        self.session.beginConfiguration()

        if self.session.inputs.count != 0{
            for i in self.session.inputs {
                self.session.removeInput(i)
            }
        }
        for i in self.cameraInput {
            if self.position == .front{
                if i.device.deviceType == self.fontCameraType{
                    if self.session.canAddInput(i){
                        self.session.addInput(i)
                    }
                }
            }else{
                if i.device.deviceType == self.backCameraType{
                    if self.session.canAddInput(i){
                        self.session.addInput(i)
                    }
                }
            }
        }
        if self.session.inputs.count == 0 && self.cameraInput.count != 0{
            self.session.addInput(self.cameraInput.first!)
            if self.position == .front{
                self.fontType = self.cameraInput.first!.device.deviceType
            }else{
                self.backType = self.cameraInput.first!.device.deviceType
            }
        }
        self.session.sessionPreset = .high
        self.session.commitConfiguration()
        self.session.startRunning()
    }
    public var fontCameraType:AVCaptureDevice.DeviceType{
        set{
            self.fontType = newValue
            self.startCapture()
        }
        get{
            self.fontType
        }
    }
    public var currentDevice:AVCaptureDevice? {
        if self.position == .front{
            return self.camera.filter { i in
                return i.deviceType == self.fontCameraType
            }.first
        }else{
            return self.camera.filter { i in
                return i.deviceType == self.backCameraType
            }.first
        }
    }
    private var fontType:AVCaptureDevice.DeviceType  = .builtInWideAngleCamera
    
    public var backCameraType:AVCaptureDevice.DeviceType{
        set{
            self.backType = newValue
            self.startCapture()
        }
        get{
            self.backType
        }
    }
    public var exposure:Exposure{
        get{
            guard let c = self.currentDevice else { return Exposure(iso: 0, during: 0)}
            return Exposure(iso: c.iso, during: c.exposureDuration.seconds)
        }
        set{
            guard let c = self.currentDevice else { return }
            do {
                try c.lockForConfiguration()
                c.exposureMode = .custom
                c.setExposureModeCustom(duration: CMTime(seconds: newValue.during, preferredTimescale: .min), iso: newValue.iso) { i in
                }
                c.unlockForConfiguration()
            } catch  {
                
            }
        }
    }
    public var maxExposureDuration:TimeInterval{
        return self.currentDevice?.activeFormat.maxExposureDuration.seconds ?? 0
    }
    public var minExposureDuration:TimeInterval{
        return self.currentDevice?.activeFormat.minExposureDuration.seconds ?? 0
    }
    private var backType:AVCaptureDevice.DeviceType = .builtInWideAngleCamera
    
    public lazy var cameraInput:[AVCaptureDeviceInput] = []
    public var exposureMode:AVCaptureDevice.ExposureMode = .autoExpose{
        didSet{
            guard let c = self.currentDevice else { return }
            do {
                try c.lockForConfiguration()
                c.exposureMode = self.exposureMode
                c.unlockForConfiguration()
            } catch  {
                
            }
           
        }
    }
    public var maxISO:Float{
        self.currentDevice?.activeFormat.maxISO ?? 0
    }
    public var minISO:Float{
        self.currentDevice?.activeFormat.minISO ?? 0
    }
    public func capture(call:@escaping CallbackBlock){
        let c = AVCaptureManualExposureBracketedStillImageSettings.manualExposureSettings(exposureDuration: CMTime(seconds: self.exposure.during, preferredTimescale: 100000), iso: self.exposure.iso)
        print(c)
        self.callback = call
        let settig = AVCapturePhotoBracketSettings(rawPixelFormatType: 0, processedFormat: nil, bracketedSettings: [c])
        self.photoOut.capturePhoto(with: settig, delegate: self)
        
    }
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let p =  photo
        guard let s = p.fileDataRepresentation() else { return }
        let a = UIImage(data: s)
        self.callback?(a)
    }
}

