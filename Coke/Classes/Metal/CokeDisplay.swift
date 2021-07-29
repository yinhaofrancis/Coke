//
//  File.swift
//  CokeVideo
//
//  Created by hao yin on 2021/2/24.
//

import Metal
import AVFoundation
import MetalKit
extension RunLoop.Mode{
    static var renderVideo:RunLoop.Mode = {
        let m = RunLoop.Mode.init("CokeVideoLayerRenderVideo")
        CFRunLoopAddCommonMode(CFRunLoopGetMain(), CFRunLoopMode(m.rawValue as CFString))
        return m
    }()
}
public protocol CokeVideoDisplayer{
    var cokePlayer:CokeVideoPlayer? {get set}
    func invalidate()
    func basicConfig()
    var videoFilter:CokeMetalFilter? { get set }
}
extension AVPlayerLayer:CokeVideoDisplayer{
    public var videoFilter: CokeMetalFilter? {
        get {
            return nil
        }
        set {
            
        }
    }
    
    
    public var cokePlayer: CokeVideoPlayer? {
        get{
            return self.player as? CokeVideoPlayer
        }
        set{
            self.player = newValue
        }
    }
    
    public func invalidate() {
        
    }
    
    public func basicConfig() {
        
    }
    
    
}
public class CokeVideoLayer:CAMetalLayer,CokeVideoDisplayer{
    public var videoFilter: CokeMetalFilter?
    
    public var showSize:CGSize{
        return CGSize(width: self.frame.size.width * UIScreen.main.scale , height: self.frame.size.height * UIScreen.main.scale)
    }

    public var ob:Any?
    public var renderScale:Float = 1
    public var queue = DispatchQueue(label: "CokeVideoLayer")
    public var cokePlayer:CokeVideoPlayer?{
        didSet{
            if self.cokePlayer != nil{
                if self.timer == nil{
                    self.timer = CADisplayLink(target: self, selector: #selector(renderVideo))
                    self.timer?.add(to: RunLoop.main, forMode: .default)
                }
                self.device = self.render.configuration.device
                self.ob = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: self.cokePlayer, queue: .main) { [weak self] n in
                    self?.timer?.invalidate()
                }
            }else{
                self.timer?.invalidate()
                self.timer = nil
                guard let ob = self.ob else { return }
                NotificationCenter.default.removeObserver(ob)
                self.ob = nil
            }
        }
    }
    @objc func renderVideo(){
        
        if let pl = self.cokePlayer,let item = pl.currentItem{
            self.queue.async {
                if let px = self.getCurrentPixelBuffer(),item.status == .readyToPlay{
                    self.render(px: px,transform: self.cokePlayer?.currentPresentTransform ?? .identity)
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
        return self.cokePlayer?.copyPixelbuffer()
    }
    public func clean(){
        self.render.vertice = nil
    }
    lazy private var videoTransformFilter:CokeMetalFilter = {
        return CokeTransformFilter(configuration: .defaultConfiguration)!
    }()
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
    }
    public override init() {
        self.render = CokeTextureRender(configuration: .defaultConfiguration)
        super.init()
    }
    public func invalidate(){
        self.timer?.invalidate()
    }
    public func render(px:CVPixelBuffer,transform:CGAffineTransform){
        guard let texture = self.render.configuration.createTexture(img: px) else { return }
        self.render(texture: texture, transform: transform)
    }
    public func render(texture:MTLTexture,transform:CGAffineTransform){
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
    public func render(image:CGImageSource) throws {
        guard let px = image.image(index: 0) else { return }
        let text = try MTKTextureLoader.init(device: self.render.configuration.device).newTexture(cgImage: px, options: nil)
        self.render(texture:text , transform: .identity)
    }
    public func render(data:Data){
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return }
        do {
            try self.render(image: source)
        } catch {
            print(error)
        }
    }

    public func basicConfig(){
        self.pixelFormat = .bgra8Unorm_srgb
        self.contentsScale = UIScreen.main.scale
        self.rasterizationScale = UIScreen.main.scale
    }
}
extension CGImageSource{
    public var orientation:CGImagePropertyOrientation{
        let i = CGImageSourceCopyProperties(self, nil)! as! Dictionary<CFString,UInt32>
        return CGImagePropertyOrientation(rawValue: i[kCGImagePropertyOrientation] ?? 0)!
    }
    public func image(index:Int)->CGImage?{
        guard let cgimg = CGImageSourceCreateImageAtIndex(self, index, nil) else{
            return nil
        }
        return cgimg
    }
}


public class CokeVideoView<layer:CALayer & CokeVideoDisplayer>:UIView{
    public override class var layerClass: AnyClass{
        return layer.self
    }
    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.black
        self.videoLayer.basicConfig()
    }
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.backgroundColor = UIColor.black
        self.videoLayer.basicConfig()
    }
    public var videoLayer:layer{
        return self.layer as! layer
    }
    deinit {
        self.videoLayer.invalidate()
    }
}
