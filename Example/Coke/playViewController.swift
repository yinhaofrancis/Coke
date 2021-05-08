//
//  playViewController.swift
//  Coke_Example
//
//  Created by hao yin on 2021/5/9.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import UIKit
import Coke
import AVFoundation

public class playViewController:UIViewController{
    
    var videoView:CokeVideoView{
        self.view as! CokeVideoView
    }
    var url:URL?
    var videoLoader:CokeVideoLoader?
    var player:CokeVideoPlayer?
    public override func viewDidLoad() {
        super.viewDidLoad()
        self.videoView.videoLayer.videoFilter = CokeGaussBackgroundFilter(configuration: .defaultConfiguration)
        guard let u = url else { return }
        do {
            self.videoLoader = try CokeVideoLoader(url: u)
            guard let asset = self.videoLoader?.asset else { return  }

            self.player = CokeVideoPlayer(playerItem: AVPlayerItem(asset: asset))
            self.videoView.videoLayer.player = self.player
            self.player?.play()
        } catch  {
            
        }
        
        
    }
}
