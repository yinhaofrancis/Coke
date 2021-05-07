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
        // Do any additional setup after loading the view.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
