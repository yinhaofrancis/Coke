//
//  File.swift
//  CokeVideo
//
//  Created by hao yin on 2021/2/24.
//

import Metal
import AVFoundation
extension RunLoop.Mode{
    static var renderVideo:RunLoop.Mode = {
        let m = RunLoop.Mode.init("CokeVideoLayerRenderVideo")
        CFRunLoopAddCommonMode(CFRunLoopGetMain(), CFRunLoopMode(m.rawValue as CFString))
        return m
    }()
}
public class CokeVideoLayer:CAMetalLayer{
    public var showSize:CGSize{
        return CGSize(width: self.frame.size.width * UIScreen.main.scale , height: self.frame.size.height * UIScreen.main.scale)
    }

    public var renderScale:Float = 1
    public var queue = DispatchQueue(label: "CokeVideoLayer")
    public var player:CokeVideoPlayer?{
        didSet{
            if self.player != nil{
                if self.timer == nil{
                    self.timer = CADisplayLink(target: self, selector: #selector(renderVideo))
                    self.timer?.add(to: RunLoop.main, forMode: .default)
                }
                self.device = self.render.configuration.device
            }else{
                self.timer?.invalidate()
                self.timer = nil
            }
        }
    }
    @objc func renderVideo(){
        
        if let pl = self.player,let item = pl.currentItem{
            self.queue.async {
                if let px = self.getCurrentPixelBuffer(),item.status == .readyToPlay{
                    self.render(px: px,transform: self.player?.currentPresentTransform ?? .identity)
                }
            }
        }else{
            self.timer?.invalidate()
            self.timer = nil
            
        }
    }
    func transformTexture(texture:MTLTexture,transform:CGAffineTransform)->MTLTexture?{
        var result:MTLTexture?
        result = texture
        if transform != .identity{
            guard let outTexture = self.videoTransformFilter.filterTexture(pixel: [texture], w: Float(texture.height), h: Float(texture.width)) else { return nil }
            result = outTexture
        }
        if let filter = self.videoFilter{
            result = filter.filterTexture(pixel: [result!], w: Float(self.showSize.width), h: Float(self.showSize.height))
        }
        return result
    }
    func getCurrentPixelBuffer()->CVPixelBuffer?{
        return self.player?.copyPixelbuffer()
    }
    public func clean(){
        self.render.vertice = nil
    }
    lazy private var videoTransformFilter:CokeMetalFilter = {
        return CokeTransformFilter(configuration: .defaultConfiguration)!
    }()
    
    public var videoFilter:CokeMetalFilter?
    private var render:CokeTextureRender
    private var timer:CADisplayLink?
    
    public init(configuration:CokeMetalConfiguration = .defaultConfiguration) {
        self.render = CokeTextureRender(configuration: configuration)
        super.init()
        self.contentsScale = UIScreen.main.scale;
    }
    public override init(layer: Any) {
        if let lay = layer as? CokeVideoLayer{
            self.videoFilter = lay.videoFilter
            self.render = lay.render
            self.timer = lay.timer
            self.renderScale = lay.renderScale
            super.init(layer: layer)
        }else{
            fatalError()
        }
    }
    required init?(coder: NSCoder) {
        self.render = CokeTextureRender(configuration: .defaultConfiguration)
        super.init(coder: coder)
        self.contentsScale = UIScreen.main.scale;
    }
    public override init() {
        self.render = CokeTextureRender(configuration: .defaultConfiguration)
        super.init()
        self.contentsScale = UIScreen.main.scale;
    }
    public func invalidate(){
        self.timer?.invalidate()
    }
    public func render(px:CVPixelBuffer,transform:CGAffineTransform){
        guard let texture = self.render.configuration.createTexture(img: px) else { return }
        guard let displayTexture = self.transformTexture(texture: texture,transform: transform) else { return }
        self.render.screenSize = self.showSize;
        guard let draw = self.nextDrawable() else { return  }
        do {
            try self.render.configuration.begin()
//            self.render.ratio = Float(displayTexture.height) / Float(displayTexture.width)
            try self.render.render(texture: displayTexture, drawable: draw)
            try self.render.configuration.commit()
        } catch {
            return
        }
    }
}

public class CokeVideoView:UIView{
    public override class var layerClass: AnyClass{
        return CokeVideoLayer.self
    }
    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.videoLayer.pixelFormat = .bgra8Unorm_srgb
        self.videoLayer.contentsScale = UIScreen.main.scale
        self.videoLayer.rasterizationScale = UIScreen.main.scale
    }
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.videoLayer.pixelFormat = .bgra8Unorm_srgb
        self.videoLayer.contentsScale = UIScreen.main.scale
        self.videoLayer.rasterizationScale = UIScreen.main.scale
    }
    public var videoLayer:CokeVideoLayer{
        return self.layer as! CokeVideoLayer
    }
    deinit {
        self.videoLayer.invalidate()
    }
}
