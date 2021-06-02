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
        list.assets = CokePhoto.shared.asset()
        list.playCallback = {[weak self] i in
            if let item = i{
                self?.play(item: item)
            }
        }
        // Do any additional setup after loading the view.
    }
    func play(item:AVPlayerItem){
        DispatchQueue.main.async {
            let a = CokePlayerViewController()
            self.present(a, animated: true, completion: nil)
            a.play(item: item)
        }
    }

}
