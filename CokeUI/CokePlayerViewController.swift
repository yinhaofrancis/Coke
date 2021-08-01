//
//  playViewController.swift
//  Coke_Example
//
//  Created by hao yin on 2021/5/9.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import UIKit
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
    private var videoView:CokeView = CokeView(frame: UIScreen.main.bounds)
    public var item:AVPlayerItem?{
        self.videoView.player?.currentItem
    }
    public var timer:Timer?
    
    public override func viewDidAppear(_ animated: Bool) {
        super .viewDidAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
    }
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
    }
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
        self.view.addSubview(self.timeControl)
        if #available(iOS 11.0, *) {
            let a = [
                self.timeControl.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor,constant: 20),
                self.timeControl.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor,constant: -20),
                self.timeControl.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor,constant: -20)
            ]
            self.view.addConstraints(a)
        } else {
            let a = [
                self.timeControl.leadingAnchor.constraint(equalTo: self.view.leadingAnchor,constant: 20),
                self.timeControl.trailingAnchor.constraint(equalTo: self.view.trailingAnchor,constant: -20),
                self.timeControl.bottomAnchor.constraint(equalTo: self.view.bottomAnchor,constant: -20)
            ]
            self.view.addConstraints(a)
        }
        

        self.timeControl.layer.masksToBounds = true;
        self.timeControl.layer.cornerRadius = 8
        self.timeControl.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        self.timeslider .addTarget(self, action: #selector(self.slideAction), for: .valueChanged)
        self.timeslider.addTarget(self, action: #selector(self.slideStart), for: .touchDown)
        self.timeslider.addTarget(self, action: #selector(self.slideEnd), for: .touchUpInside)
        self.timeslider.addTarget(self, action: #selector(self.slideEnd), for: .touchUpOutside)
        self.timer?.invalidate()
        self.timer = Timer .scheduledTimer(withTimeInterval: 2, repeats: false, block: {[weak self] t in
            self?.timeControl.isHidden = true
        })
    }
    private var observer:Any?
    lazy var timeControl:UIView = {
       let v = UIView()
        v.addSubview(self.timeslider)
        v.translatesAutoresizingMaskIntoConstraints = false
        let a = [
            self.timeslider.leadingAnchor.constraint(equalTo: v.leadingAnchor,constant: -15),
            self.timeslider.trailingAnchor.constraint(equalTo: v.trailingAnchor,constant: 15),
            self.timeslider.topAnchor.constraint(equalTo: v.topAnchor,constant: -20),
            self.timeslider.bottomAnchor.constraint(equalTo: v.bottomAnchor,constant: 20)
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
    private func currentTime(time:CMTime){
        guard let s = self.item?.duration.seconds else { return }
        let p = time.seconds / s
        self.timeslider.value = Float(p)
    }
    public func play(item:AVPlayerItem){
        self.videoView.play(item: item)
        if let ob = self.observer{
            self.videoView.player?.removeTimeObserver(ob)
        }
        self.observer = self.videoView.player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.01, preferredTimescale: .max), queue: DispatchQueue.main, using: { [weak self]t in
            
            guard let ws = self else { return }
            if ws.isseek == false{
                ws.currentTime(time: t)
            }
        })
    }
    public func play(url:URL) {
        self.videoView.play(url: url)
        if let ob = self.observer{
            self.videoView.player?.removeTimeObserver(ob)
        }
        self.observer = self.videoView.player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.01, preferredTimescale: .max), queue: DispatchQueue.main, using: { [weak self]t in
            
            guard let ws = self else { return }
            if ws.isseek == false{
                ws.currentTime(time: t)
            }
        })
        self.videoView.play()
    }
    public func showImage(data:Data){
        self.videoView.videoLayer.render(data: data)
    }
    @objc func slideStart(){
        self.isseek = true
        self.videoView.player?.pause()
        self.timer?.invalidate()
        self.timeControl.isHidden = false
    }
    var isseek:Bool = false
    @objc func slideEnd(){
        self.isseek = false
        self.videoView.player?.play()
        self.timer?.invalidate()
        self.timer = Timer .scheduledTimer(withTimeInterval: 2, repeats: false, block: {[weak self] t in
            self?.timeControl.isHidden = true
        })
    }
    @objc func slideAction(){
        self.videoView.player?.percent = Double(self.timeslider.value)
        self.timeControl.isHidden = false
    }
    deinit {
        guard let ob = self.observer else { return }
        self.videoView.player?.removeTimeObserver(ob)
    }
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.timer?.invalidate()
        
        super.touchesEnded(touches, with: event)
        self.timeControl.isHidden = false
        self.timer = Timer .scheduledTimer(withTimeInterval: 2, repeats: false, block: {[weak self] t in
            self?.timeControl.isHidden = true
        })
    }
    
}

