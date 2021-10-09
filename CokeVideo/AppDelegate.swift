//
//  AppDelegate.swift
//  CokeVideo
//
//  Created by wenyang on 2021/7/30.
//

import UIKit
import Coke
let id = "com.coke.look"
@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    let task = CokeRefreshTask(name: id)
    
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        task.schedule()
        return true
    }
    func applicationDidEnterBackground(_ application: UIApplication) {
        task.request()
    }
}


