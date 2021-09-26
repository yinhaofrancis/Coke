//
//  CokeMetalFilter.swift
//  CokeVideo
//
//  Created by hao yin on 2021/3/24.
//

import Foundation
import Metal
import MetalPerformanceShaders
import CoreVideo
public protocol CokeMetalFilter{
    func filter(pixel:CVPixelBuffer)->CVPixelBuffer?
    func filterTexture(pixel:[MTLTexture],w:Float,h:Float)->MTLTexture?
}
public struct RenderFragmentUniform{
    var bias:Float;
};
public class CokeGaussBackgroundFilter:CokeMetalFilter{
    public var hasBackground:Bool
    public func filter(pixel: CVPixelBuffer) -> CVPixelBuffer? {
        autoreleasepool {
            guard let px1 = self.coke.configuration.createTexture(img: pixel) else { return nil }
            guard let px = self.filterTexture(pixel: [px1], w: self.w, h: self.h) else { return nil }
            return CokeMetalConfiguration.createPixelBuffer(texture: px)
        }
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
                if(w / h == ow / oh){
                    return px1
                }
                guard let px2 = self.coke.configuration.createTexture(width: Int(w), height: Int(h),store: .private) else { return nil }
                guard let px3 = self.coke.configuration.createTexture(width: Int(w), height: Int(h),store: .private) else { return nil }
                guard let px4 = self.coke.configuration.createTexture(width: Int(w), height: Int(h),store: renderImediatly ? .private : .shared) else { return nil }
                guard let bias = self.buffer else { return nil }
                let buffer = try self.coke.configuration.begin()
                
                let psize =  MTLSize(width: Int(ow * max(h / oh , w / ow)), height: Int(oh * max(h / oh , w / ow)), depth: 1)
                
//                if #available(iOS 13.0, *){
//                
//                }else{
//                    self.hasBackground = false
//                }
                if self.hasBackground{
                    try self.coke.compute(name: "imageScaleToHeightFill", buffer: buffer, pixelSize:psize, buffers: [], textures: [px1,px2])
                    try self.coke.compute(name: "imageExposure", buffer: buffer, pixelSize: psize, buffers: [bias], textures: [px2,px3])
                    self.blur.encode(commandBuffer: buffer, sourceTexture: px3, destinationTexture: px4)
                    try self.coke.compute(name: "imageScaleToWidthFill",buffer:buffer, pixelSize: psize, buffers: [], textures: [px1,px4])
                }else{
                    try self.coke.compute(name: "imageScaleToFit",buffer:buffer, pixelSize: psize, buffers: [], textures: [px1,px4])
                }
                
                try self.coke.configuration.commit(buffer: buffer)
                return px4
                
            } catch  {
                return nil
            }
        }
    }
    public init?(configuration:CokeMetalConfiguration,sigma:Float = 40,imediately:Bool = true,hasBackground:Bool = true) {
        do {
            self.coke = try CokeComputer(configuration: configuration)
            self.blur = MPSImageGaussianBlur(device: configuration.device, sigma: sigma)
            self.renderImediatly = imediately
            self.hasBackground = hasBackground
        } catch  {
            return nil
        }
    }
    public var w:Float = 720
    public var h:Float = 1280
    public var coke:CokeComputer
    public var blur:MPSImageGaussianBlur
    public var bias:RenderFragmentUniform = RenderFragmentUniform(bias: -1)
    public var renderImediatly:Bool
    public lazy var buffer:MTLBuffer? = {
        self.coke.configuration.createBuffer(data: self.bias)
    }()
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
                guard let px3 = self.Coke.configuration.createTexture(width: Int(w), height: Int(h),store: .private) else { return nil }
                let cmdbuffer = try self.Coke.configuration.begin()
                if(self.buffer == nil){
                    self.buffer = self.Coke.configuration.createBuffer(data: self.transform)
                }
                if let buffer = self.buffer{
                    try self.Coke.compute(name: "imageTransform",buffer: cmdbuffer, pixelSize: MTLSize(width: Int(w), height: Int(h), depth: 1), buffers: [buffer], textures: [px1,px3])
                }
                try self.Coke.configuration.commit(buffer: cmdbuffer)
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
