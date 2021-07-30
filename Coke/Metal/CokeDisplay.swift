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
public protocol CokeVideoDisplayer:AnyObject{
    var cokePlayer:CokeVideoPlayer? {get set}
    func invalidate()
    func basicConfig()
    var videoFilter:CokeMetalFilter? { get set }
    func render(image:CGImageSource) throws
    func render(data:Data)
}
extension AVPlayerLayer:CokeVideoDisplayer{
    public func render(image: CGImageSource) throws {
        guard let px = image.image(index: 0) else { return }
        self.contentsGravity = CALayerContentsGravity.resizeAspect
        self.contents = px
    }
    
    public var videoFilter: CokeMetalFilter? {
        get {
            return nil
        }
        set {
            
        }
    }
    public func render(data:Data){
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return }
        do {
            try self.render(image: source)
        } catch {
            print(error)
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
    public var cokePlayer:CokeVideoPlayer?{
        didSet{
            if self.cokePlayer != nil{
                if self.timer == nil{
                    self.timer = CADisplayLink(target: self, selector: #selector(renderVideo))
                    self.thread = Thread(block: { [weak self] in
                        self?.timer?.add(to:RunLoop.current , forMode: .default)
                        RunLoop.current.run()
                    })
                    self.thread?.start()
                }
                self.device = self.render.configuration.device
                self.ob = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: self.cokePlayer, queue: .main) { [weak self] n in
                    self?.timer?.invalidate()
                    self?.thread?.cancel()
                }
            }else{
                self.timer?.invalidate()
                self.timer = nil
                self.thread?.cancel()
                guard let ob = self.ob else { return }
                NotificationCenter.default.removeObserver(ob)
                self.ob = nil
            }
        }
    }
    @objc func renderVideo(){
        autoreleasepool {
            if let pl = self.cokePlayer,let item = pl.currentItem{
                if let pixelBuffer = self.getCurrentPixelBuffer(),item.status == .readyToPlay{
                    self.render(pixelBuffer: pixelBuffer,transform: self.cokePlayer?.currentPresentTransform ?? .identity)
                }
            }else{
                self.timer?.invalidate()
                self.timer = nil
                self.thread?.cancel()
            }
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
    private var thread:Thread?
    private var runloop:RunLoop?
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
        self.thread?.cancel()
        self.timer = nil
    }
    public func render(pixelBuffer:CVPixelBuffer,transform:CGAffineTransform){
        guard let texture = self.render.configuration.createTexture(img: pixelBuffer) else { return }
        self.render(texture: texture, transform: transform)
    }
    public func render(texture:MTLTexture,transform:CGAffineTransform){
        
        guard let displayTexture = self.transformTexture(texture: texture,transform: transform) else { return }
        self.render.screenSize = self.showSize;
        guard let draw = self.nextDrawable() else { return  }
        do {
            try self.render.configuration.begin()
            try self.render.render(texture: displayTexture, drawable: draw)
            try self.render.configuration.commit()
        } catch {
            return
        }
    }
    public func render(image:CGImageSource) throws {
        if let t = self.timer,t.isPaused == false{
            return
        }
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
        self.pixelFormat = CokeConfig.metalColorFormat
        self.contentsScale = UIScreen.main.scale
        self.rasterizationScale = UIScreen.main.scale
    }
    deinit {
        self.thread?.cancel()
        self.timer?.invalidate()
        self.timer = nil
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
