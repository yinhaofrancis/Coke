//
//  AppDelegate.swift
//  CokeVideo
//
//  Created by wenyang on 2021/7/30.
//

import UIKit
import Coke
import CoreMedia
let id = "com.coke.look"
@main
class AppDelegate: UIResponder, UIApplicationDelegate {


    
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }
    
    public static var sample:[CMSampleBuffer] = []
    
//    public static var audio:[CokeAudioConverterAAC.OutputBuffer] = []
    
    public static var desc = AudioStreamBasicDescription()
}


