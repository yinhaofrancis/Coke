//
//  CokeVideoRender.swift
//  CokeVideo
//
//  Created by hao yin on 2021/2/20.
//

import Metal
import simd
import MetalPerformanceShaders
import MetalKit

public class CokeTextureRender {
    public struct vertex{
        public var location:simd_float4
        public var texture:simd_float2
    }
    public struct WorldState{
        public var world:simd_float4x4
        public var camera:simd_float4x4
    }
    public let configuration:CokeMetalConfiguration
    private let pipelineDescriptor:MTLRenderPipelineDescriptor
    private var pipelineState:MTLRenderPipelineState?
    public init(configuration:CokeMetalConfiguration = CokeMetalConfiguration.defaultConfiguration)  {
        self.configuration = configuration
        let pipelineDesc = MTLRenderPipelineDescriptor()
        pipelineDesc.vertexFunction = configuration.function(name: "vertexShader")
        pipelineDesc.fragmentFunction = configuration.function(name: "fragmentShader")
        pipelineDesc.colorAttachments[0].pixelFormat = CokeConfig.metalColorFormat
        
        self.pipelineDescriptor = pipelineDesc
        pipelineDesc.vertexDescriptor = self.vertexDescriptor;
        self.scale(x: 1, y: 1, z: 1)
    }
    public var screenSize:CGSize = CGSize(width: 320, height: 480)

    public var rectangle:[vertex] {
        let w:Float = 1
        let h:Float = 1
        return [
            vertex(location: simd_float4(-w, h, 0, 1), texture: simd_float2(0, 0)),
            vertex(location: simd_float4(w, h, 0, 1), texture: simd_float2(1, 0)),
            vertex(location: simd_float4(w, -h, 0, 1), texture: simd_float2(1, 1)),
            vertex(location: simd_float4(-w, -h, 0, 1), texture: simd_float2(0, 1))
        ]
    }
    public var worldState:WorldState = {
        return WorldState(world: simd_float4x4(1), camera: simd_float4x4(1))
    }()
    public var fragmentState:RenderFragmentUniform = {
        return RenderFragmentUniform(bias: 0.5)
    }()
    public var vertice:MTLBuffer?
    
    public lazy var indexVertice:MTLBuffer? = {
        return self.configuration.device.makeBuffer(bytes: rectangleIndex, length: rectangleIndex.count * MemoryLayout<UInt32>.size, options: .storageModeShared)
    }()
    public lazy var samplerState:MTLSamplerState? = {
        let sample = MTLSamplerDescriptor()
        sample.mipFilter = .linear
        sample.magFilter = .linear
        sample.minFilter = .linear
        return self.configuration.device.makeSamplerState(descriptor: sample)
    }()
    public lazy var vertexDescriptor:MTLVertexDescriptor = {
        let vd = MTLVertexDescriptor()
        vd.attributes[0].format = .float4
        vd.attributes[0].offset = 0;
        vd.attributes[0].bufferIndex = 0;
        vd.attributes[1].format = .float2
        vd.attributes[1].offset = MemoryLayout<simd_float4>.stride
        vd.attributes[1].bufferIndex = 0
        vd.layouts[0].stride = MemoryLayout<vertex>.stride
        vd.layouts[0].stepRate = 1;
        vd.layouts[0].stepFunction = .perVertex
        return vd
    }()
    public var rectangleIndex:[UInt32]{
        [
            0,3,1,2
        ]
    }
    
    private var viewPort:MTLViewport?
    public func render(image:CGImage,drawable:CAMetalDrawable) throws{
        
        let text = try MTKTextureLoader.init(device: self.configuration.device).newTexture(cgImage: image, options: nil)
        try self.render(texture: text, drawable: drawable)
    }
    
    public func render(texture:MTLTexture,drawable:CAMetalDrawable) throws{
        let renderPass = MTLRenderPassDescriptor()
        if(self.vertice == nil){
            self.vertice = self.configuration.device.makeBuffer(bytes: rectangle, length: MemoryLayout<vertex>.stride * rectangle.count, options: .storageModeShared)
        }
        renderPass.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
        renderPass.colorAttachments[0].storeAction = .store
        renderPass.colorAttachments[0].loadAction = .load
        renderPass.colorAttachments[0].texture = drawable.texture
        
        guard let encoder = self.configuration.commandbuffer?.makeRenderCommandEncoder(descriptor: renderPass) else { throw NSError(domain: "start encoder fail", code: 0, userInfo: nil)}
        if self.viewPort == nil{
            self.viewPort = MTLViewport(originX: 0, originY: 0, width: Double(self.screenSize.width), height: Double(self.screenSize.height)
                                  , znear: -1, zfar: 1)
        }
        encoder.setViewport(self.viewPort!)
        if self.pipelineState == nil{
            self.pipelineState = try configuration.device.makeRenderPipelineState(descriptor: self.pipelineDescriptor)
        }
        guard let pipelinestate = self.pipelineState else { encoder.endEncoding();return}
        encoder.setRenderPipelineState(pipelinestate)
        encoder.setVertexBuffer(self.vertice, offset: 0, index: 0)
        encoder.setVertexBytes(&self.worldState, length: MemoryLayout.stride(ofValue: self.worldState), index: 1)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentSamplerState(self.samplerState, index: 0)
        if let indexb = self.indexVertice{
            encoder.drawIndexedPrimitives(type: .triangleStrip, indexCount: rectangleIndex.count, indexType: .uint32, indexBuffer: indexb, indexBufferOffset: 0)
        }
        encoder.endEncoding()
        self.configuration.commandbuffer?.present(drawable)
    }
    public func scale(x:Float,y:Float,z:Float){
        let a = simd_float4x4([
            SIMD4(x,0,0,0),
            SIMD4(0,y,0,0),
            SIMD4(0,0,z,0),
            SIMD4(0,0,0,1),
        ])
        self.worldState.world = a
    }
}


