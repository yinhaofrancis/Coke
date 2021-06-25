//
//  CokeCompute.swift
//  CokeVideo
//
//  Created by hao yin on 2021/2/24.
//

import Metal
import simd
import MetalPerformanceShaders

public class CokeComputer{
    public var device:MTLDevice{
        self.configuration.device
    }
    public var queue:MTLCommandQueue{
        self.configuration.queue
    }
    
    
    public let configuration:CokeMetalConfiguration
    public init(configuration:CokeMetalConfiguration = CokeMetalConfiguration.defaultConfiguration) throws {
        self.configuration = configuration
    }
    
    public func compute(name:String,pixelSize:MTLSize? = nil,buffers:[MTLBuffer] = [],textures:[MTLTexture] = []) throws{
        try self.startEncoder(name: name,callback: { (encoder) in
            
            
            if(textures.count > 0){
                encoder .setTextures(textures, range: 0 ..< textures.count)
            }
            if(buffers.count > 0){
                encoder.setBuffers(buffers, offsets: (0 ..< buffers.count).map({_ in 0}), range: 0 ..< buffers.count)
            }
            if let gsize = pixelSize{
                let w = self.device.maxThreadsPerThreadgroup.width
                let dw = Int(ceil(Double(gsize.width) / Double(w)))
                let s = MTLSize(width: dw, height: gsize.height, depth: 1)
                let threadW = Int(ceil(Double(gsize.width / dw)))
                let g = MTLSize(width: threadW, height: 1, depth: 1)
                encoder.dispatchThreadgroups(s, threadsPerThreadgroup: g)
                
            }
            encoder.endEncoding()
            
        })
    }
    public typealias EncoderBlock = (MTLComputeCommandEncoder) throws ->Void
    public func startEncoder(name:String,callback:EncoderBlock)throws{
        guard let function = self.configuration.shaderLibrary.makeFunction(name: name) else {
            throw NSError(domain: "can't load function \(name)", code: 0, userInfo: nil)
        }
        let state = try self.device.makeComputePipelineState(function: function)
        guard let cmdBuffer = self.configuration.commandbuffer else {
            throw NSError(domain: "you should call begin before startEncorder", code: 0, userInfo: nil)
        }
        guard let encoder = cmdBuffer.makeComputeCommandEncoder() else {
            throw NSError(domain: "you should create command Encoder", code: 0, userInfo: nil)
        }
        encoder.setComputePipelineState(state)
        try callback(encoder)
    }
    public func encoderTexture(encoder:MTLComputeCommandEncoder,textures:[MTLTexture]){
        if textures.count > 0{
            encoder.setTextures(textures, range: 0 ..< textures.count)
        }
    }
    
}
