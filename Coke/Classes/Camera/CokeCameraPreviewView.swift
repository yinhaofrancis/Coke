//
//  CokeCameraPreviewView.swift
//  Coke
//
//  Created by hao yin on 2021/5/7.
//

import UIKit
import AVFoundation
public class CokeCameraPreviewView: CokeVideoView,AVCaptureVideoDataOutputSampleBufferDelegate{

    weak var camera:CokeCamera?
    public var ratio:CGFloat = 0
    public func setCamera(ca:CokeCamera){
        ca.videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global())
        self.camera = ca
        guard let c = self.camera?.currentDevice else { return }
        try? c.lockForConfiguration()
        c.focusMode = .continuousAutoFocus
        c.isSmoothAutoFocusEnabled = true
        c.unlockForConfiguration()
    }
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        DispatchQueue.main.async {
            guard let px = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            self.ratio = CGFloat(CVPixelBufferGetWidth(px)) / CGFloat(CVPixelBufferGetHeight(px))
            self.videoLayer.render(px: px, transform: CGAffineTransform(rotationAngle: .pi / 2).concatenating(CGAffineTransform(translationX: 0, y: -CGFloat(CVPixelBufferGetWidth(px)))))
        }
    }
    public var displayFrame:CGRect{
        let hw = self.ratio
        let h = self.bounds.size.width  * hw
        let x = (self.bounds.size.width - self.bounds.size.width) / 2
        let y = (self.bounds.size.height - h) / 2
        return CGRect(x: x, y: y, width: self.bounds.size.width, height: h)
    }
    public var focusPoint:CGPoint{
        get{
            guard let c = self.camera?.currentDevice else { return .zero }
            let df = self.displayFrame
            let x = df.width * (1 - c.focusPointOfInterest.y) + df.origin.x
            let y = df.height * (c.focusPointOfInterest.x) + df.origin.y
            return CGPoint(x: x, y: y)
        }
        set{
            guard let c = self.camera?.currentDevice else { return }
            if c.isFocusPointOfInterestSupported {
                let df = self.displayFrame
                let n = newValue
                let x = (n.x - df.origin.x) / df.width
                let y = (n.y - df.origin.y) / df.height
                do{
                    try c.lockForConfiguration()
                    c.isSmoothAutoFocusEnabled = true
                    
                    c.focusPointOfInterest = CGPoint(x: y, y: 1 - x)
                    c.focusMode = .continuousAutoFocus
                    c.isSmoothAutoFocusEnabled = true
                    c.unlockForConfiguration()
                }catch{
                    
                }
            }
        }
    }
    
    public var exposurePoint:CGPoint{
        get{
            guard let c = self.camera?.currentDevice else { return .zero }
            let df = self.displayFrame
            let x = df.width * (1 - c.exposurePointOfInterest.y) + df.origin.x
            let y = df.height * (c.exposurePointOfInterest.x) + df.origin.y
            return CGPoint(x: x, y: y)
        }
        set{
            guard let c = self.camera?.currentDevice else { return }
            if c.isFocusPointOfInterestSupported {
                let df = self.displayFrame
                let n = newValue
                let x = (n.x - df.origin.x) / df.width
                let y = (n.y - df.origin.y) / df.height
                do{
                    try c.lockForConfiguration()
                    c.exposurePointOfInterest = CGPoint(x: y, y: 1 - x)
                    c.exposureMode = .continuousAutoExposure
                    c.unlockForConfiguration()
                }catch{
                    
                }
            }
        }
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard let p = touches.first?.location(in: self) else { return }
        self.focusPoint = p
        self.exposurePoint = p
    }
}
