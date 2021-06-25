//
//  CokeRender.swift
//  CokeVideo
//
//  Created by hao yin on 2021/3/25.
//

import Metal
import MetalKit

public class CokeRender{
    public var configuration:CokeMetalConfiguration
    public var screenSize:CGSize = UIScreen.main.bounds.size
    public var renderPipelineDescriptor:MTLRenderPipelineDescriptor
    public var currentEncoder:MTLRenderCommandEncoder?
    public var currentDrawble:CAMetalDrawable?
    public lazy var samplerState:MTLSamplerState? = {
        let sample = MTLSamplerDescriptor()
        sample.mipFilter = .linear
        sample.magFilter = .linear
        sample.minFilter = .linear
        return self.configuration.device.makeSamplerState(descriptor: sample)
    }()
    public init(config:CokeMetalConfiguration = .defaultConfiguration) {
        self.configuration = config
        self.renderPipelineDescriptor  = MTLRenderPipelineDescriptor()
        self.renderPipelineDescriptor.colorAttachments[0].pixelFormat = .rgba8Unorm_srgb
        self.renderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        self.renderPipelineDescriptor.stencilAttachmentPixelFormat = .stencil8
        
    }
    public func configDisplayLayer(layer:CAMetalLayer){
        layer.pixelFormat = .rgba8Unorm_srgb;
    }
    public func begin(drawable:CAMetalDrawable) throws {
        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
        renderPass.colorAttachments[0].storeAction = .dontCare
        renderPass.colorAttachments[0].loadAction = .clear
        renderPass.colorAttachments[0].texture = drawable.texture
        renderPass.depthAttachment.clearDepth = 1.0
        guard let encoder = self.configuration.commandbuffer?.makeRenderCommandEncoder(descriptor: renderPass) else { throw NSError(domain: "start encoder fail", code: 0, userInfo: nil)}
        self.currentEncoder = encoder
        self.currentDrawble = drawable
        encoder.setViewport(MTLViewport(originX: 0, originY: 0, width: Double(self.screenSize.width), height: Double(self.screenSize.height)
                                        , znear: -1, zfar: 1))
    }
    public func render(object:CokeObject) throws {
        guard let encoder = self.currentEncoder else { throw NSError(domain: "no encoder please call begin", code: 0, userInfo: nil) }
        self.renderPipelineDescriptor.fragmentFunction = nil
        self.renderPipelineDescriptor.fragmentFunction = self.configuration.shaderLibrary.makeFunction(name: object.fragmentFunction)
        self.renderPipelineDescriptor.vertexFunction = nil
        self.renderPipelineDescriptor.vertexFunction = self.configuration.shaderLibrary.makeFunction(name: object.vertexFunction)
        self.renderPipelineDescriptor.vertexDescriptor = object.vertexDescriptor
        let state = try self.configuration.device.makeRenderPipelineState(descriptor: self.renderPipelineDescriptor)
        encoder.setRenderPipelineState(state)
        encoder.setFragmentSamplerState(self.samplerState, index: 0)
        encoder.setVertexBuffer(object.vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentTexture(object.colorTexture, index: 0)
        encoder.drawPrimitives(type: object.primitiveType, vertexStart: 0, vertexCount: object.verticeCount)
    }
    public func commit() throws {
        self.currentEncoder?.endEncoding()
        guard let cd = self.currentDrawble else { throw NSError(domain: "no drawable", code: 0, userInfo: nil) }
        self.configuration.commandbuffer?.present(cd)
    }
}
public class CokeObject{
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
    public init(buffer:MTLBuffer,
                verticeCount:Int,
                primitiveType:MTLPrimitiveType,
                colorTexture:MTLTexture,
                renderPipelineState:MTLRenderPipelineDescriptor,
                vertexFunction:String,
                fragmentFunction:String){
        self.vertexBuffer = buffer
        self.vertexFunction = vertexFunction
        self.fragmentFunction = fragmentFunction
        self.colorTexture = colorTexture
        self.primitiveType = primitiveType
        self.verticeCount = verticeCount
    }
    public var transform:float4x4 = float4x4(rows: [
        simd_float4(1, 0, 0, 0),
        simd_float4(0, 1, 0, 0),
        simd_float4(0, 0, 1, 0),
        simd_float4(0, 0, 0, 1)
        
    ])
    public var vertexFunction:String
    public var fragmentFunction:String
    public var vertexBuffer:MTLBuffer
    public var colorTexture:MTLTexture
    public var primitiveType:MTLPrimitiveType
    public var verticeCount:Int
}
