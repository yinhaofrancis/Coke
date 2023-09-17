//
//  CokeModelViewController.swift
//  CokeVideo
//
//  Created by wenyang on 2023/9/16.
//

import UIKit
import Coke

public class CokeModelViewController:UIViewController {
    
    public var modelView:CokeModelView{
        return self.view as! CokeModelView
    }
    var display:CokeRenderDisplay?
    let render = try! CokeModelRender()
    let ticker = FrameTicker.shared
    lazy var content:[CokeBoxModel] = {[
        try! CokeBoxModel(render: self.render,diff: "diff",specular: "specular"),
        try! CokeBoxModel(render: self.render,diff: "diff",specular: "specular"),
        try! CokeBoxModel(render: self.render,diff: "diff",specular: "specular"),
        try! CokeBoxModel(render: self.render,diff: "diff",specular: "specular"),
        try! CokeBoxModel(render: self.render,diff: "diff",specular: "specular"),
        try! CokeBoxModel(render: self.render,diff: "diff",specular: "specular"),
        try! CokeBoxModel(render: self.render,diff: "diff",specular: "specular"),
        try! CokeBoxModel(render: self.render,diff: "diff",specular: "specular"),
        try! CokeBoxModel(render: self.render,diff: "diff",specular: "specular"),
        try! CokeBoxModel(render: self.render,diff: "diff",specular: "specular"),
        try! CokeBoxModel(render: self.render,diff: "diff",specular: "specular"),
        try! CokeBoxModel(render: self.render,diff: "diff",specular: "specular"),
    ]  }()
    
    var v:Float = 0
    public override func viewDidLoad() {
        super.viewDidLoad()
        self.modelView.render = render
        self.display = self.modelView.display
        self.ticker.addCallback(sender: self, sel: #selector(run))
    }
    @objc public func run(){
        guard let display = self.display else { return }
        let c = CokeScene(position: [0,10,-15], cameraRotate: [-0.3,0,0], lightPos: [0,0,0],lightDir: [-1,-1,1], aspect: self.ratio)
        v += 0.03
        self.render.render(display: display) { encoder in
            c.encoder(encoder: encoder)
            var offset:Float = 0
            var h:Float = 0
            for i in content{
                offset += 0.3
                h += 1
                i.scale = [1,1,1]
                i.translate = [h * cos(v * (offset)),h,h * sin(v * (offset))]
                i.rotate = [4 * sin(v * h / 50),4 * cos(v * h / 50),4 * sin(v * h / 50)]
                i.render(encoder: encoder)
            }
            
        }
    }
    public var ratio:Float{
        if Thread.isMainThread{
            return Float(self.view.frame.width / self.view.frame.height)
        }else{
            var v:Float = 1;
            DispatchQueue.main.sync {
                v = Float(self.view.frame.width / self.view.frame.height)
            }
            return v
        }
        
    }
}
