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

public class CokeSlider:UISlider{
    public var lineWidth:CGFloat = 2
    public var inset:CGFloat{
        thumbSize / 2
    }
    public var thumbSize:CGFloat = 64
    open override func minimumValueImageRect(forBounds bounds: CGRect) -> CGRect{
        return CGRect(x: inset, y: 0, width: thumbSize, height: bounds.height)
    }

    open override func maximumValueImageRect(forBounds bounds: CGRect) -> CGRect{
        return CGRect(x: bounds.width - inset, y: 0, width: thumbSize, height: bounds.height)
    }

    open override func trackRect(forBounds bounds: CGRect) -> CGRect{
        return CGRect(x: inset, y: (bounds.height - lineWidth) / 2, width: bounds.width - 2 * inset, height: lineWidth)
    }

    open override func thumbRect(forBounds bounds: CGRect, trackRect rect: CGRect, value: Float) -> CGRect{
        let percent = value / (self.maximumValue  - self.minimumValue)
        let space = bounds.width - thumbSize
        let r = CGRect(x: rect.minX + space * CGFloat(percent) - thumbSize / 2, y: rect.minY + (lineWidth - thumbSize) / 2, width: thumbSize, height: thumbSize)
        return r
    }
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        self.setThumbImage(self.thumbImg, for: .normal)
        self.setThumbImage(self.thumbImg, for: .highlighted)
        self.minimumTrackTintColor = UIColor(white: 0.9, alpha: 1)
        self.maximumTrackTintColor = UIColor(white: 0.9, alpha: 0.8)
    }
    public lazy var thumbImg:UIImage? = {
        let ss:CGFloat = 12
//        UIGraphicsBeginImageContextWithOptions(_ size: CGSize, _ opaque: Bool, _ scale: CGFloat)
        UIGraphicsBeginImageContextWithOptions(CGSize(width: self.thumbSize, height: self.thumbSize), false, UIScreen.main.scale)
        UIColor.white.setFill()
        let ctx = UIGraphicsGetCurrentContext()
        ctx?.setShadow(offset: .zero, blur: 2)
        UIBezierPath(ovalIn: CGRect(x: (self.thumbSize - ss) / 2, y: (self.thumbSize - ss) / 2, width: ss, height: ss)).fill()
        let imge = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return imge
    }()
}


public class CokePlayerViewController:UIViewController{
    
    private var videoView:CokeVideoView = CokeVideoView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    public private(set) var item:AVPlayerItem?
    public private(set) var videoLoader:CokeVideoLoader?
    public private(set) var player:CokeVideoPlayer?
    public private(set) var filter = CokeGaussBackgroundFilter(configuration: .defaultConfiguration)
    public override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addSubview(self.videoView)
        let vl = [
            self.videoView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.videoView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.videoView.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.videoView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
        ]
        self.videoView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addConstraints(vl)
        self.videoView.videoLayer.videoFilter = filter
        self.view.addSubview(self.timeControl)
        let a = [
            self.timeControl.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.timeControl.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.timeControl.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ]
        self.view .addConstraints(a)
        self.timeslider .addTarget(self, action: #selector(self.slideAction), for: .valueChanged)
        self.timeslider.addTarget(self, action: #selector(self.slideStart), for: .touchDown)
        self.timeslider.addTarget(self, action: #selector(self.slideEnd), for: .touchUpInside)
        self.timeslider.addTarget(self, action: #selector(self.slideEnd), for: .touchUpOutside)
    }
    private var observer:Any?
    lazy var timeControl:UIView = {
       let v = UIView()
        v.addSubview(self.timeslider)
        v.translatesAutoresizingMaskIntoConstraints = false
        let a = [
            self.timeslider.leadingAnchor.constraint(equalTo: v.leadingAnchor),
            self.timeslider.trailingAnchor.constraint(equalTo: v.trailingAnchor),
            self.timeslider.topAnchor.constraint(equalTo: v.topAnchor),
            self.timeslider.bottomAnchor.constraint(equalTo: v.bottomAnchor)
        ]
        v.addConstraints(a)
        return v
    }()
    
    lazy var timeslider:UISlider = {
        let s = CokeSlider(frame: .zero)
        s.translatesAutoresizingMaskIntoConstraints = false
        s.maximumValue = 1
        s.minimumValue = 0
        return s
    }()
    public var percent:Double{
        get{
            Double((self.item?.currentTime() ?? .zero).seconds / (self.item?.duration.seconds ?? 1))
        }
        set{
            guard let sec = self.item?.duration.seconds else { return }
            self.item?.seek(to:CMTime(seconds: newValue * sec, preferredTimescale: .max), toleranceBefore: CMTime(seconds: .zero, preferredTimescale: .max), toleranceAfter: CMTime(seconds: .zero, preferredTimescale: .max), completionHandler: nil)
        }
    }
    private func currentTime(time:CMTime){
        guard let s = self.item?.duration.seconds else { return }
        let p = time.seconds / s
        DispatchQueue.main.async {
            self.timeslider.value = Float(p)
        }
    }
    public func play(url:URL) {
        do {
            self.videoLoader = try CokeVideoLoader(url: url)
            guard let asset = self.videoLoader?.asset else { return }
            self.item = AVPlayerItem(asset: asset)
            self.player = CokeVideoPlayer(playerItem: self.item)
            if let ob = self.observer{
                self.player?.removeTimeObserver(ob)
            }
            self.observer = self.player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.01, preferredTimescale: .max), queue: DispatchQueue.global(qos: .background), using: { [weak self]t in
                
                guard let ws = self else { return }
                if ws.isseek == false{
                    ws.currentTime(time: t)
                }
                
                
            })
            self.videoView.videoLayer.player = self.player
            self.player?.play()
        } catch  {
            
        }
        
    }
    @objc func slideStart(){
        self.isseek = true
        self.player?.pause()
    }
    var isseek:Bool = false
    @objc func slideEnd(){
        self.isseek = false
        self.player?.play()
    }
    @objc func slideAction(){
        self.percent = Double(self.timeslider.value)
    }
    deinit {
        guard let ob = self.observer else { return }
        self.player?.removeTimeObserver(ob)
    }
}
