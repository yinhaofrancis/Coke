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
    
    public var commandbuffer:MTLCommandBuffer?
    
    
    public init() throws{
        let device:MTLDevice? = MTLCreateSystemDefaultDevice()
        guard let dev = device else { throw NSError(domain: "can't create metal context", code: 0, userInfo: nil) }
        self.device = dev
        guard let queue = dev.makeCommandQueue(maxCommandBufferCount: 2) else { throw NSError(domain: "can't create metal command queue", code: 0, userInfo: nil)}
        self.queue = queue
        try self.loadDefaultLibrary()
    }
    private func loadDefaultLibrary() throws{
        guard let url =  Bundle(for: CokeComputer.self).url(forResource: "default", withExtension: "metallib")?.path else { throw NSError(domain: "can't load default metal lib", code: 0, userInfo: nil) }
        self.shaderLibrary = try self.device.makeLibrary(filepath:url)
    }
    public var shaderLibrary:MTLLibrary!
    
    public func begin() throws {
        guard let commandbuffer = self.queue.makeCommandBuffer() else { throw NSError(domain: " can't create command buffer", code: 0, userInfo: nil)}
        self.commandbuffer = commandbuffer
    }
    
    public func commit() throws {
        self.commandbuffer?.commit()
        self.commandbuffer?.waitUntilCompleted()
        
    }
    
    
    public static var defaultConfiguration:CokeMetalConfiguration{
        return try! CokeMetalConfiguration()
    }
    
    private var textureCache:CVMetalTextureCache?
    
    public func createTexture(img:CVPixelBuffer,usage:MTLTextureUsage = [.shaderRead,.shaderWrite])->MTLTexture?{
        let d = MTLTextureDescriptor()
        d.pixelFormat = CokeConfig.metalColorFormat
        
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
    
    public func createCVPixelBuffer(img:CGImage)->CVPixelBuffer?{
        let option = [
//            kCVPixelBufferCGImageCompatibilityKey:true,
//            kCVPixelBufferCGBitmapContextCompatibilityKey:true,
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
