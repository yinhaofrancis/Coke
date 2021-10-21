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
    var showCover:Bool { get set }
    func invalidate()
    func basicConfig(rect:CGRect)
    var videoFilter:CokeMetalFilter? { get set }
    func render(image:CGImageSource) throws
    func render(data:Data)
    func render(image:CGImage) throws
    func resume()
    func clean()
}
extension AVPlayerLayer:CokeVideoDisplayer{
    public func clean() {
        
    }
    
    public var showCover: Bool {
        get {
            return false
        }
        set {
            
        }
    }
    
    public func resume() {
        self.player?.play()
    }
    
    public func render(image: CGImage) {
        self.contentsGravity = CALayerContentsGravity.resizeAspect
        self.contents = image
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
    public func render(image: CGImageSource) throws {
        guard let px = image.image(index: 0) else { throw NSError(domain: "no image", code: 0, userInfo: nil) }
        self.render(image: px)
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
        self.player?.pause()
    }
    
    public func basicConfig(rect:CGRect) {
        self.frame = rect
    }
}
public class CokeVideoLayer:CAMetalLayer,CokeVideoDisplayer{
    public var showCover: Bool = true
    
    public func resume() {
        FrameTicker.shared.addCallback(sender: self, sel: #selector(renderVideo))
    }
    public var videoFilter: CokeMetalFilter?
    public var pixelBuffer:CVPixelBuffer?
    public var showSize:CGSize{
        return CGSize(width: self.frame.size.width * UIScreen.main.scale , height: self.frame.size.height * UIScreen.main.scale)
    }

    
    public var renderScale:Float = 1
    public var cokePlayer:CokeVideoPlayer?{
        didSet{
            if self.cokePlayer != nil{
                self.device = self.render.configuration.device
                self.renderDefaultCover()
            }
        }
    }
    @objc func renderVideo(){
        autoreleasepool {
            if let pl = self.cokePlayer,let item = pl.currentItem{
                if let pixelBuffer = self.getCurrentPixelBuffer() ,item.status == .readyToPlay{
                    self.pixelBuffer = pixelBuffer
                    self.render(pixelBuffer: pixelBuffer,transform: self.cokePlayer?.currentPresentTransform ?? .identity)
                }else{
                    guard let px = self.pixelBuffer else { return }
                    self.render(pixelBuffer: px,transform: self.cokePlayer?.currentPresentTransform ?? .identity)
                }
            }
        }
    }
    func renderLast() {
        
        FrameTicker.shared.perform { [weak self] in
            guard let last = self?.lastPixel else { return }
            self?.render(texture: last,transform: self?.cokePlayer?.currentPresentTransform ?? .identity)
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
        self.pixelBuffer = nil
    }
    lazy private var videoTransformFilter:CokeMetalFilter = {
        return CokeTransformFilter(configuration: .defaultConfiguration)!
    }()
    private var render:CokeTextureRender
    private var observer:Any?
    private var lastPixel:MTLTexture?
    public init(configuration:CokeMetalConfiguration = .defaultConfiguration) {
        self.render = CokeTextureRender(configuration: configuration)
        super.init()
        self.contentsScale = UIScreen.main.scale;
    }
    public override init(layer: Any) {
        if let lay = layer as? CokeVideoLayer{
            self.videoFilter = lay.videoFilter
            self.render = lay.render
            self.renderScale = lay.renderScale
            super.init(layer: layer)
            self.startNotificationScreen()
        }else{
            fatalError()
        }
    }
    required init?(coder: NSCoder) {
        self.render = CokeTextureRender(configuration: .defaultConfiguration)
        super.init(coder: coder)
        self.startNotificationScreen()
    }
    public override init() {
        self.render = CokeTextureRender(configuration: .defaultConfiguration)
        super.init()
        self.startNotificationScreen()
    }
    public func invalidate(){
        self.cokePlayer?.pause()
    }
    private func startNotificationScreen(){
        self.observer = NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main) {[weak self] n in
            self?.renderLast()
        }
    }
    private func stopNotificationScreen(){
        if let ob = self.observer{
            NotificationCenter.default.removeObserver(ob)
        }
        
    }
    public func render(pixelBuffer:CVPixelBuffer,transform:CGAffineTransform){
        guard let texture = self.render.configuration.createTexture(img: pixelBuffer) else { return }
        self.lastPixel = texture
        self.render(texture: texture, transform: transform)
    }
    public func render(texture:MTLTexture,transform:CGAffineTransform){
        
        guard let displayTexture = self.transformTexture(texture: texture,transform: transform) else { return }
        self.render.screenSize = self.showSize;
        guard let draw = self.nextDrawable() else { return  }
        do {
            let buffer = try self.render.configuration.begin()
            try self.render.render(texture: displayTexture, drawable: draw, buffer: buffer)
            self.render.configuration.commit(buffer: buffer)
        } catch {
            return
        }
    }
    public func render(image:CGImageSource) throws {
        guard let px = image.image(index: 0) else { return }
        try self.render(image: px)
    }
    public func render(image: CGImage) throws {
        FrameTicker.shared.perform { [weak self] in
            guard let ws = self else  { return }
            guard let text = try? MTKTextureLoader.init(device: ws.render.configuration.device).newTexture(cgImage: image, options: [.SRGB:false]) else { return }
            ws.lastPixel = text
            ws.render(texture:text , transform: .identity)
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
    public func renderDefaultCover(){
        if self.showCover {
            guard let asset = self.cokePlayer?.currentItem?.asset else { return }
            guard let t = self.cokePlayer?.currentItem?.currentTime() else { return }
            AVAssetImageGenerator.init(asset: asset).generateCGImagesAsynchronously(forTimes: [NSValue(time: t)]) { _, img, _, _, _ in
                
                guard let image = img else { return }
                try? self.render(image: image)
            }
        }
    }

    public func basicConfig(rect:CGRect){
        self.pixelFormat = CokeConfig.metalColorFormat
        self.contentsScale = UIScreen.main.scale
        self.rasterizationScale = UIScreen.main.scale
    }
    deinit {
        self.stopNotificationScreen()
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

public class CokeSampleLayer:CALayer,CokeVideoDisplayer{
    public func clean() {
        
    }
    
    public var showCover: Bool = false
    public func resume() {
        FrameTicker.shared.addCallback(sender: self, sel: #selector(renderBackground))
        self.cokePlayer?.play()
    }
    
    
    private var mainDisplay:AVPlayerLayer = AVPlayerLayer()    
    public var cokePlayer:CokeVideoPlayer?{
        didSet{
            self.mainDisplay.cokePlayer = self.cokePlayer
            FrameTicker.shared.addCallback(sender: self, sel: #selector(renderBackground))
            
        }
    }
    
    public func invalidate(){
        self.cokePlayer?.pause()
    }
    
    public func basicConfig(rect:CGRect){
        self.contentsScale = UIScreen.main.scale
        self.rasterizationScale = UIScreen.main.scale
        self.frame = rect
    }
    
    
    public var videoFilter: CokeMetalFilter?
    
    public override var frame: CGRect{
        didSet{
            self.mainDisplay.frame = self.bounds
            self.addSublayer(mainDisplay)
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
    @objc public func renderBackground(){
        guard let px = self.cokePlayer?.copyPixelbuffer() else { return }
        guard let img = self.filter(img:CIImage(cvImageBuffer: px)) else { return }
        try? self.render(image: img)
    }
    public func render(image: CGImageSource) throws {
        try self.mainDisplay.render(image: image)
        guard let cgimg = CGImageSourceCreateImageAtIndex(image, 0, nil) else { throw NSError(domain: "fail", code: 0, userInfo: nil)}
        try self.render(image: cgimg)
    }
    public func render(image:CGImage) throws{
        self.contentsGravity = .resizeAspectFill
        let cimg =  self.filter(img: CIImage(cgImage: image))
        self.masksToBounds = true
        DispatchQueue.main.async {
            self.contents = cimg
        }
    }
    
    private var context:CIContext = CIContext()
    private func filter(img:CIImage,radius:CGFloat = 20,exp:CGFloat = -1)->CGImage?{
        let filter = CIFilter(name: "CIGaussianBlur")
        let expfilter = CIFilter(name: "CIExposureAdjust")
        filter?.setValue(radius, forKey: "inputRadius")
        expfilter?.setValue(exp, forKey: "inputEV")
        filter?.setValue(img, forKey: kCIInputImageKey)
        expfilter?.setValue(filter?.outputImage, forKey: kCIInputImageKey)
        guard let ciimg = expfilter?.outputImage else { return nil }
        return context.createCGImage(ciimg, from: img.extent)
    }
    public func renderDefaultCover(){
        if self.showCover {
            guard let asset = self.cokePlayer?.currentItem?.asset else { return }
            guard let t = self.cokePlayer?.currentItem?.currentTime() else { return }
            AVAssetImageGenerator.init(asset: asset).generateCGImagesAsynchronously(forTimes: [NSValue(time: t)]) { _, img, _, _, _ in
                
                guard let image = img else { return }
                try? self.render(image: image)
            }
        }
    }
}

public class FrameTicker{
    private var timer:CADisplayLink!
    private var thread:Thread!
    private var runloop:RunLoop!
    private var framesPerSecond:Int?
    private weak var sender:AnyObject?
    private var sel:Selector?
    public static let shared:FrameTicker = FrameTicker()
    private var queue:DispatchQueue = {
        return DispatchQueue(label: "FrameTicker", qos: .userInitiated, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)
    }()
    public func addCallback(sender:AnyObject?,sel:Selector){
        self.sender = sender
        self.sel = sel
    }
    public func perform(_ call:@escaping ()->Void){
        if let rp = self.runloop{
            rp.perform(call)
        }
    }
    init(framesPerSecond:Int? = nil) {
        
        let lock:UnsafeMutablePointer<pthread_mutex_t> = .allocate(capacity: 1)
        pthread_mutex_init(lock, nil)
        
        pthread_mutex_lock(lock)
        self.framesPerSecond = framesPerSecond
        if timer == nil{
            self.timer = CADisplayLink(target: self, selector: #selector(callback))
            
            if let fs = self.framesPerSecond{
                self.timer?.preferredFramesPerSecond = fs
            }
            
            self.thread = Thread(block: {
                self.timer?.add(to:RunLoop.current , forMode: .common)
                self.runloop  = RunLoop.current
                self.callback()
                pthread_mutex_unlock(lock)
                RunLoop.current.run()
            })
            self.thread.threadPriority = 1.0
            self.thread.qualityOfService = .userInteractive
            self.thread?.start()
        }
        pthread_mutex_lock(lock)
        pthread_mutex_destroy(lock)
        lock.deallocate()
    }
    @objc func callback(){
        self.queue.async {
            if let sel = self.sel{
                _ = self.sender?.perform(sel)
            }
        }
    }
    
}
