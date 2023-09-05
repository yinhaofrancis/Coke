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
    
    public override class var layerClass: AnyClass{
        return AVSampleBufferDisplayLayer.self
    }
}
