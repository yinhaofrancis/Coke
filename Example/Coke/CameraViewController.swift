//
//  CameraViewController.swift
//  Coke_Example
//
//  Created by hao yin on 2021/5/7.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import UIKit
import Coke
class CameraViewController: UIViewController {

    @IBOutlet weak var exp: UISlider!
    @IBOutlet weak var iso: UISlider!
    let camera:CokeCamera = CokeCamera()
    @IBOutlet weak var ccv: CokeCameraPreviewView!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.ccv.setCamera(ca: self.camera)
        iso.maximumValue = camera.maxISO
        iso.minimumValue = camera.minISO
        
//        exp.minimumValue = camera.
        self.camera.startCapture()
        self.camera.exposureMode = .continuousAutoExposure
    }
    @IBAction func sliderAction(_ sender: UISlider) {
        exp.maximumValue = Float(camera.maxExposureDuration)
        exp.minimumValue = Float(camera.minExposureDuration)
        camera.exposure = CokeCamera.Exposure(iso: self.iso.value, during: TimeInterval(self.exp.value))
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "display" {
            let des = segue.destination as! DisplayViewController
            des.img = sender as? UIImage
        }
    }
    @IBAction func capture(_ sender: Any) {
        self.camera.capture { i in
            self.performSegue(withIdentifier: "display", sender: i)
        }
    }
}
