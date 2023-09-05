//
//  CodeSampleDisplay.swift
//  Coke
//
//  Created by wenyang on 2023/9/5.
//

import AVFoundation
import UIKit

public class CokeSampleView:UIView{
    public var sampleLayer:AVSampleBufferDisplayLayer{
        return self.layer as! AVSampleBufferDisplayLayer
    }
    
    public var render:AVSampleBufferAudioRenderer = {
        AVSampleBufferAudioRenderer()
    }()
    
    public lazy var sync:AVSampleBufferRenderSynchronizer = {
        let a = AVSampleBufferRenderSynchronizer()
        a.addRenderer(self.render)
        a.addRenderer(self.sampleLayer)
        return a;
    }()
    
    public override class var layerClass: AnyClass{
        return AVSampleBufferDisplayLayer.self
    }
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        _ = self.sync
    }
    public func enqueue(sample:CMSampleBuffer){
        if sample.mediaType == kCMMediaType_Audio{
            self.render.enqueue(sample)
        }else{
            self.sampleLayer.enqueue(sample)
        }
    }
}

