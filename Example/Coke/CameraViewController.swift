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
    var ecoder:CokeVideoEncoder?
    var file:FileHandle?
    override func viewDidLoad() {
        super.viewDidLoad()
        self.ccv.setCamera(ca: self.camera)
        self.ecoder = try? CokeVideoEncoder(width: 360, height: 720)
        let u = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("aaa").appendingPathExtension("h264")
        FileManager.default.createFile(atPath: u.path, contents: nil, attributes: nil)
        file = try! FileHandle(forUpdating: u)
        self.ecoder?.setCallback { [weak self]cm in
            guard let d = cm else { return }
            self?.file?.write(d)
        }
        iso.maximumValue = camera.maxISO
        iso.minimumValue = camera.minISO
        self.camera.delegates.append(self.ecoder!)
//        exp.minimumValue = camera.
        self.camera.startCapture()
        self.camera.exposureMode = .continuousAutoExposure
        
        exp.maximumValue = Float(camera.maxExposureDuration) * 5
        exp.minimumValue = Float(camera.minExposureDuration)
    }
    @IBAction func sliderAction(_ sender: UISlider) {
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
    deinit {
        self.ecoder = nil
    }
}
