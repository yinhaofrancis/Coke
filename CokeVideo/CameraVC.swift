//
//  CameraVC.swift
//  CokeVideo
//
//  Created by hao yin on 2022/1/12.
//

import UIKit
import Coke
public class CameraVC:UIViewController{
    lazy var cam:CokeCamera =  {
        try! CokeCamera(dataOut: self.encoder)
    }()
    lazy var  encoder:VideoEncoder = {
        let a = try! VideoEncoder(configuration: H264Configuration())
        a.dataOut = layer
        return a
    }()
    
    lazy var layer:VideoDisplayLayer = VideoDisplayLayer()
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.view.layer .addSublayer(self.layer)
        self.layer.frame = self.view.bounds
    }
    public override func viewDidLoad() {
        super.viewDidLoad()
        self.cam.start()
    }
    deinit{
        self.encoder.stop()
    }
}
