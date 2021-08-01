//
//  PhotosViewController.swift
//  Coke_Example
//
//  Created by hao yin on 2021/6/1.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import UIKit
import Coke
import AVKit
class PhotosViewController: UIViewController {

    let list = CokePhotoView(frame: UIScreen.main.bounds)
    var track:CokeAssetVideoTrack?
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addSubview(list)
        let c = [
            list.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            list.topAnchor.constraint(equalTo: self.view.topAnchor),
            list.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            list.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
        ]
        list.translatesAutoresizingMaskIntoConstraints = false;
        self.view.addConstraints(c)
        list.assets = CokePhoto.shared.asset(type: .video)
        list.playCallback = {[weak self] i in
            guard  let ass = i?.asset else { return }
            self?.track = try? CokeAssetVideoTrack(asset: ass)
            let filter = CokeGaussBackgroundFilter(configuration: .defaultConfiguration ,imediately: false)
            self?.track?.filter = filter
            filter?.w = 720
            filter?.h = 960
            
            try? self?.track?.export(w: 720, h: 960, callback: { u, s in
                guard let url = u else { return }
                DispatchQueue.main.async {
                    let a = AVPlayerViewController()
                    a.player = AVPlayer(url: url)
                    a.player?.play()
                    self?.present(a, animated: true, completion: nil)
                }
            })
//            self?.track?.ready()
        }
        // Do any additional setup after loading the view.
    }
    func play(item:AVPlayerItem){
        DispatchQueue.main.async {
            let a = CokePlayerViewController()
            self.show(a, sender: nil)
            a.play(item: item)
        }
    }

}
