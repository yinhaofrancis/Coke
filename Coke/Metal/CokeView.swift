//
//  File.swift
//  CokeVideo
//
//  Created by hao yin on 2021/2/25.
//

import Metal
import MetalKit
import Foundation
import UIKit
import AVFoundation

open class CokeView:UIView{
    public var videoLoader:CokeVideoLoader?
    private var item:AVPlayerItem?
    var player:CokeVideoPlayer?{
        get{
            self.videoLayer.cokePlayer
        }
        set{
            self.videoLayer.cokePlayer = newValue
        }
    }
    public var filter:CokeMetalFilter?{
        get{
            return self.videoLayer.videoFilter
        }
        set{
            self.videoLayer.videoFilter = newValue
        }
    }
    public override class var layerClass: AnyClass{
        if CokeView.useMetal{
            return CokeVideoLayer.self
        }else{
            return AVPlayerLayer.self
        }
    }
    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.black
        self.player = CokeVideoPlayer()
        self.videoLayer.basicConfig(rect: self.bounds)
        if CokeView.useMetal{
            self.filter = CokeGaussBackgroundFilter(configuration: .defaultConfiguration)
        }else{
            self.filter = CokeGaussBackgroundFilter(configuration: .defaultConfiguration,imediately: false)
        }

    }

    public static func systemCheck<T,W>(model1:Int32,model2:Int32,type:T.Type,map:((UnsafeMutablePointer<T>)->W))->W?{
        let model = UnsafeMutablePointer<Int32>.allocate(capacity: 2)
        model.update(repeating: model1, count: 1)
        model.advanced(by: 1).update(repeating: model2, count: 1)
        var count:Int = 1024
        let b = UnsafeMutableRawPointer.allocate(byteCount: 1024, alignment: 1)
        let rs = sysctl(model, 2, b, &count, nil, 0)
        if(rs == 0){
            return map(b.assumingMemoryBound(to: type))
        }
        return nil
    }
    public static func systemCheck(model1:Int32,model2:Int32)->String?{
        self.systemCheck(model1: model1, model2: model2, type: CChar.self) { t in
            String(cString: t)
        }
    }
    public static func memory() -> Double{
        Double(ProcessInfo.processInfo.physicalMemory) / 1024 / 1024
    }
    public static var machine:String{
        var ts = utsname()
        uname(&ts)
        return Mirror(reflecting: ts.machine).children.reduce(into: "") { r, i in
            r.append(String(UnicodeScalar(UInt8(i.value as? Int8 ?? 0))))
        }
    }
    public static var sysname:String{
        var ts = utsname()
        uname(&ts)
        return Mirror(reflecting: ts.sysname).children.reduce(into: "") { r, i in
            r.append(String(UnicodeScalar(UInt8(i.value as? Int8 ?? 0))))
        }
    }
    public static var version:String{
        var ts = utsname()
        uname(&ts)
        return Mirror(reflecting: ts.version).children.reduce(into: "") { r, i in
            r.append(String(UnicodeScalar(UInt8(i.value as? Int8 ?? 0))))
        }
    }
    public static var nodename:String{
        var ts = utsname()
        uname(&ts)
        return Mirror(reflecting: ts.nodename).children.reduce(into: "") { r, i in
            r.append(String(UnicodeScalar(UInt8(i.value as? Int8 ?? 0))))
        }
    }
    public static var useMetal:Bool{
        if self.machine.contains("iPhone"){
            let str = self.machine
            guard let v1 = self.machine[str.index(str.startIndex, offsetBy: 6) ..< str.endIndex].components(separatedBy: ",").first else {
                return false
            }
            return Int(v1) ?? 0 > 6
        }else if self.machine.contains("iPad"){
            let str = self.machine
            guard let v1 = self.machine[str.index(str.startIndex, offsetBy: 4) ..< str.endIndex].components(separatedBy: ",").first else {
                return false
            }
            return Int(v1) ?? 0 > 4
        }else{
            return true
        }
    }
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.backgroundColor = UIColor.black
        self.player = CokeVideoPlayer()
        self.videoLayer.basicConfig(rect: self.bounds)
    }
    
    public var videoLayer:CokeVideoDisplayer{
        return self.layer as! CokeVideoDisplayer
    }
    deinit {
        self.videoLayer.invalidate()
    }
    public func loadUrl(url:URL){
        do {
            self.videoLayer.clean()
            self.videoLoader = try CokeVideoLoader(url: url)
            if let asset = self.videoLoader?.asset{
                self.item = AVPlayerItem(asset: asset)
            }
            self.videoLoader?.image(se: 0, callback: { img in
                guard let ig = img else { return }
                try? self.videoLayer.render(image: ig)
            })
        } catch  {
            
        }
    }
    public func play(item:AVPlayerItem){
        self.item = item
        self.play()
    }
    public func play(){
        
        self.player?.replaceCurrentItem(with: self.item)
        self.player?.play()
        self.videoLayer.resume()
    }
    public func pause(){
        self.player?.pause()
    }
    open override func layoutSubviews() {
        super.layoutSubviews()
        self.videoLayer.basicConfig(rect: self.bounds)
    }
}
open class CokeVideoView<layer:CALayer & CokeVideoDisplayer>:UIView{
    public var videoLoader:CokeVideoLoader?
    private var item:AVPlayerItem?
    private var player:CokeVideoPlayer?{
        get{
            self.videoLayer.cokePlayer
        }
        set{
            self.videoLayer.cokePlayer = newValue
        }
    }
    public var filter:CokeMetalFilter?{
        get{
            return self.videoLayer.videoFilter
        }
        set{
            self.videoLayer.videoFilter = newValue
        }
    }
    public override class var layerClass: AnyClass{
        return layer.self
    }
    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.black
        self.player = CokeVideoPlayer()
        self.videoLayer.basicConfig(rect: self.bounds)
        
        self.filter = CokeGaussBackgroundFilter(configuration: .defaultConfiguration)

    }
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.backgroundColor = UIColor.black
        self.player = CokeVideoPlayer()
        self.videoLayer.basicConfig(rect: self.bounds)
    }
    public var videoLayer:layer{
        return self.layer as! layer
    }
    deinit {
        self.videoLayer.invalidate()
    }
    public func play(url:URL) {
        do {
            self.videoLoader = try CokeVideoLoader(url: url)
            guard let asset = self.videoLoader?.asset else { return }
            self.play(item: AVPlayerItem(asset: asset))
            
        } catch  {
            
        }
    }
    public func loadUrl(url:URL){
        do {
            self.videoLoader = try CokeVideoLoader(url: url)
            if let asset = self.videoLoader?.asset{
                self.item = AVPlayerItem(asset: asset)
            }
        } catch  {
            
        }
    }
    public func play(item:AVPlayerItem){
        self.item = item
        self.play()
    }
    public func play(){
        self.player?.replaceCurrentItem(with: self.item)
        self.player?.pause()
        self.player?.play()
        self.videoLayer.resume()
    }
    public func pause(){
        self.player?.pause()
    }
    open override func layoutSubviews() {
        super.layoutSubviews()
        self.videoLayer.basicConfig(rect: self.bounds)
    }
}
