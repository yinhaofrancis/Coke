//
//  CokeConfiguration.swift
//  CokeVideo
//
//  Created by hao yin on 2021/2/24.
//

import Foundation

import Metal
import simd
import MetalPerformanceShaders
import CoreVideo

public class CokeMetalConfiguration{
    public var device:MTLDevice
    public var queue:MTLCommandQueue
    public var semphone:DispatchSemaphore
    public init(drawCallsCount:Int = 3) throws{
        let device:MTLDevice? = MTLCreateSystemDefaultDevice()
        guard let dev = device else { throw NSError(domain: "can't create metal context", code: 0, userInfo: nil) }
        self.device = dev
        guard let queue = dev.makeCommandQueue(maxCommandBufferCount: 2) else { throw NSError(domain: "can't create metal command queue", code: 0, userInfo: nil)}
        self.queue = queue
        self.semphone = DispatchSemaphore(value: drawCallsCount)
        try self.loadDefaultLibrary()
    }
    private func loadDefaultLibrary() throws{
        self.shaderLibrary = try self.device.makeDefaultLibrary(bundle: Bundle(for: CokeComputer.self))
    }
    public var shaderLibrary:MTLLibrary!
    
    public func begin() throws ->MTLCommandBuffer {
        
        let a = self.semphone.wait(timeout: .now() + .milliseconds(100))
        if a == .timedOut{
            throw NSError(domain: "draw call waiting timeout", code: 1)
        }
        guard let commandbuffer = self.queue.makeCommandBuffer() else { throw NSError(domain: " can't create command buffer", code: 0, userInfo: nil)}
        commandbuffer.enqueue()
        return commandbuffer
    }
    
    public func commit(buffer:MTLCommandBuffer) {
        buffer .addCompletedHandler { _ in
            self.semphone.signal()
        }
        buffer.commit()
    }
    public func function(name:String)->MTLFunction?{
        if let a = self.map[name]{
            return a
        }else{
            guard let f = self.shaderLibrary.makeFunction(name: name) else { return nil }

            self.map[name] = f
            return f
        }
    }
    private var map:Map<String,MTLFunction> = Map()
    
    public static var defaultConfiguration:CokeMetalConfiguration{
        return try! CokeMetalConfiguration()
    }
    
    private var textureCache:CVMetalTextureCache?
    
    public func createTexture(img:CVPixelBuffer,pixelFormat:MTLPixelFormat? = nil,usage:MTLTextureUsage = [.shaderRead,.shaderWrite])->MTLTexture?{
        let d = MTLTextureDescriptor()
        d.pixelFormat = pixelFormat ?? CokeConfig.metalColorFormat
        
        d.width = CVPixelBufferGetWidth(img)
        d.storageMode = .shared
        d.usage = usage
        d.height = CVPixelBufferGetHeight(img)
        var mt:CVMetalTexture?
        if(textureCache == nil){
            var c:CVMetalTextureCache?
            CVMetalTextureCacheCreate(nil, nil, self.device, nil, &c)
            self.textureCache = c
        }
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, self.textureCache!, img, nil, d.pixelFormat, d.width, d.height, 0, &mt)
            
        if(status == kCVReturnSuccess) {
            return CVMetalTextureGetTexture(mt!)
        }
        return nil
    }
    
    public func createTexture(width:Int,height:Int,usage:MTLTextureUsage =  [.shaderRead,.shaderWrite],store:MTLStorageMode = .shared)->MTLTexture?{
        let d = MTLTextureDescriptor()
        d.pixelFormat = CokeConfig.metalColorFormat
        d.width = width
        d.storageMode = store
        d.usage = usage
        d.height = height
        return self.device.makeTexture(descriptor: d)
    }
    public func createDepthTexture(width:Int,height:Int)->MTLTexture?{
        let d = MTLTextureDescriptor()
        d.pixelFormat = CokeConfig.metalDepthFormat
        d.width = width
        d.storageMode = .private
        d.usage = .renderTarget
        d.height = height
        return self.device.makeTexture(descriptor: d)
    }
    
    
    public func createCVPixelBuffer(img:CGImage)->CVPixelBuffer?{
        let option = [
            kCVPixelBufferMetalCompatibilityKey:true,
            kCVPixelBufferPixelFormatTypeKey:CokeConfig.videoColorFormat,
        ] as [CFString : Any]
        if let data = img.dataProvider?.data{
            
            let dp = UnsafeMutablePointer<UInt8>.allocate(capacity: CFDataGetLength(data))
            CFDataGetBytes(data, CFRange(location: 0, length: CFDataGetLength(data)), dp)
            var buffer:CVPixelBuffer?
            CVPixelBufferCreateWithBytes(nil, img.width, img.height, CokeConfig.videoColorFormat, dp, img.bytesPerRow, nil, nil, option as CFDictionary, &buffer)
            return buffer
        }
        
        return nil
    }
    public func createBuffer<T>(data:[T])->MTLBuffer?{
        let buffer = self.device.makeBuffer(length: MemoryLayout<T>.size * data.count, options: .storageModeShared)
        let ptr = buffer?.contents()
        for i in 0 ..< data.count {
            ptr?.storeBytes(of: data[i], toByteOffset: i * MemoryLayout<T>.size, as: T.self)
        }
        return buffer
    }
    
    public func createBuffer<T>(data:T)->MTLBuffer?{
        let buffer = self.device.makeBuffer(length: MemoryLayout<T>.size, options: .storageModeShared)
        buffer?.contents().storeBytes(of: data, as: T.self)
        return buffer
    }
    public func createBuffer(size:Int)->MTLBuffer?{
        return self.device.makeBuffer(length: size, options: .storageModeShared)
    }
    public class func createPixelBuffer(texture:MTLTexture)->CVPixelBuffer?{
        var px:CVPixelBuffer?
        let r = CVPixelBufferCreate(nil, texture.width, texture.height, CokeConfig.videoColorFormat, nil, &px)
        if(r == kCVReturnSuccess){
            CVPixelBufferLockBaseAddress(px!, CVPixelBufferLockFlags(rawValue: 0))
            if let ptr = CVPixelBufferGetBaseAddress(px!){
                texture.getBytes(ptr, bytesPerRow: 4 * texture.width, from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
                CVPixelBufferUnlockBaseAddress(px!, CVPixelBufferLockFlags(rawValue: 0))
                return px
            }else{
                
                CVPixelBufferUnlockBaseAddress(px!, CVPixelBufferLockFlags(rawValue: 0))
                return nil
            }
        }
        return nil
    }
    public func createTexture(img:CGImage)->MTLTexture?{
        guard let a = self.createCVPixelBuffer(img: img) else { return nil }
        return self.createTexture(img: a)
    }
}
public class Map<K:Hashable,V>{
    private var dic:Dictionary<K,V> = Dictionary()
    private var rw:UnsafeMutablePointer<pthread_rwlock_t> = .allocate(capacity: 1)
    
    public init(){
        pthread_rwlock_init(self.rw, nil)
    }
    public subscript(key:K)->V?{
        get{
            pthread_rwlock_rdlock(self.rw)
            let n = dic
            pthread_rwlock_unlock(self.rw)
            return n[key]
        }
        set{
            pthread_rwlock_wrlock(self.rw)
            self.dic[key] = newValue
            pthread_rwlock_unlock(self.rw)
        }
    }
    deinit {
        pthread_rwlock_destroy(self.rw)
        self.rw.deallocate()
    }
    public func clean(){
        pthread_rwlock_wrlock(self.rw)
        self.dic.removeAll()
        pthread_rwlock_unlock(self.rw)
    }
}
