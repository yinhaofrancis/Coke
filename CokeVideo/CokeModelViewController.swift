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
    lazy var content = { try! CokeBoxModel(render: self.render) }()
    public override func viewDidLoad() {
        super.viewDidLoad()
        self.modelView.render = render
        self.display = self.modelView.display
        self.ticker.addCallback(sender: self, sel: #selector(run))
    }
    @objc public func run(){
        guard let display = self.display else { return }
        self.render.render(display: display) { encoder in
            content.render(encoder: encoder)
        }
    }
}
