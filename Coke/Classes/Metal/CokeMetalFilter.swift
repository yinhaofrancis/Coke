//
//  CokeMetalFilter.swift
//  CokeVideo
//
//  Created by hao yin on 2021/3/24.
//

import Foundation
import Metal
import MetalPerformanceShaders

public protocol CokeMetalFilter{
    func filter(pixel:CVPixelBuffer)->CVPixelBuffer?
    func filterTexture(pixel:[MTLTexture],w:Float,h:Float)->MTLTexture?
}
public class CokeGaussBackgroundFilter:CokeMetalFilter{
    public func filter(pixel: CVPixelBuffer) -> CVPixelBuffer? {
        guard let px1 = self.Coke.configuration.createTexture(img: pixel) else { return nil }
        guard let px = self.filterTexture(pixel: [px1], w: self.w, h: self.h) else { return nil }
        return CokeMetalConfiguration.createPixelBuffer(texture: px)
    }
    
    public func filterTexture(pixel:[MTLTexture],w:Float,h:Float)->MTLTexture?{
        autoreleasepool { () -> MTLTexture? in
            if(pixel.count < 1){
                return nil
            }
            do {
                let ow = Float(pixel.first!.width)
                let oh = Float(pixel.first!.height)
                let px1 = pixel.first!
                guard let px2 = self.Coke.configuration.createTexture(width: Int(w), height: Int(h),store: .private) else { return nil }
                guard let px3 = self.Coke.configuration.createTexture(width: Int(w), height: Int(h)) else { return nil }
                try self.Coke.configuration.begin()
                let psize =  MTLSize(width: Int(ow * max(h / oh , w / ow)), height: Int(oh * max(h / oh , w / ow)), depth: 1)
                try self.Coke.compute(name: "imageScaleToFill", pixelSize:psize, buffers: [], textures: [px1,px2])
                
                self.blur.encode(commandBuffer: self.Coke.configuration.commandbuffer!, sourceTexture: px2, destinationTexture: px3)
                try self.Coke.compute(name: "imageScaleToFit", pixelSize: psize, buffers: [], textures: [px1,px3])
                try self.Coke.configuration.commit()
                return px3
                
            } catch  {
                return nil
            }
        }
    }
    public init?(configuration:CokeMetalConfiguration,sigma:Float = 30) {
        do {
            self.Coke = try CokeComputer(configuration: configuration)
            self.blur = MPSImageGaussianBlur(device: configuration.device, sigma: sigma)
        } catch  {
            return nil
        }
    }
    public var w:Float = 720
    public var h:Float = 1280
    public var Coke:CokeComputer
    public var blur:MPSImageGaussianBlur
}
public class CokeTransformFilter:CokeMetalFilter{
    
    private var transform:simd_float3x3 = simd_float3x3([
                                            simd_float3(1, 0, 0),
                                            simd_float3(0, 1, 0),
                                            simd_float3(0, 0, 1)
    ]){
        didSet{
            self.buffer = self.Coke.configuration.createBuffer(data: self.transform)
        }
    }
    public var buffer:MTLBuffer?
    public func filter(pixel: CVPixelBuffer) -> CVPixelBuffer? {
        return nil
    }
    
    public func filterTexture(pixel: [MTLTexture], w: Float, h: Float) -> MTLTexture? {
        if(pixel.count < 1){
            return nil
        }
        return autoreleasepool { () -> MTLTexture? in
            do {
                let px1 = pixel.first!
                self.transform = simd_float3x3([
                                                simd_float3(0, -1,0),
                                                simd_float3(1, 0, 0),
                                                simd_float3(0, w, 1)])
                guard let px3 = self.Coke.configuration.createTexture(width: Int(w), height: Int(h)) else { return nil }
                try self.Coke.configuration.begin()
                if(self.buffer == nil){
                    self.buffer = self.Coke.configuration.createBuffer(data: self.transform)
                }
                if let buffer = self.buffer{
                    try self.Coke.compute(name: "imageTransform", pixelSize: MTLSize(width: Int(w), height: Int(h), depth: 1), buffers: [buffer], textures: [px1,px3])
                }
                try self.Coke.configuration.commit()
                return px3
                
            } catch  {
                return nil
            }
        }
    }
    
    public init?(configuration:CokeMetalConfiguration) {
        do {
            self.Coke = try CokeComputer(configuration: configuration)
        } catch  {
            return nil
        }
    }
    public var Coke:CokeComputer
}
