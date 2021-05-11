//
//  DisplayViewController.swift
//  Coke_Example
//
//  Created by hao yin on 2021/5/7.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import UIKit

class DisplayViewController: UIViewController {
    var img:UIImage?
    @IBOutlet weak var image: UIImageView!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.image.image = img
    }
}
