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
var a:Float = 0.0
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
    private let depthStencilDescriptor:MTLDepthStencilDescriptor
    private let depthStencilState:MTLDepthStencilState
    private var pipelineState:MTLRenderPipelineState?
    public init(configuration:CokeMetalConfiguration = CokeMetalConfiguration.defaultConfiguration)  {
        self.configuration = configuration
        let pipelineDesc = MTLRenderPipelineDescriptor()
        pipelineDesc.vertexFunction = configuration.function(name: "vertexShader")
        pipelineDesc.fragmentFunction = configuration.function(name: "fragmentShader")
        pipelineDesc.colorAttachments[0].pixelFormat = CokeConfig.metalColorFormat
        pipelineDesc.depthAttachmentPixelFormat = .depth32Float_stencil8
        pipelineDesc.stencilAttachmentPixelFormat = .depth32Float_stencil8
        let dsd = MTLDepthStencilDescriptor()
        dsd.depthCompareFunction = .lessEqual
        dsd.isDepthWriteEnabled = true;
        self.depthStencilDescriptor = dsd
        self.pipelineDescriptor = pipelineDesc
        self.depthStencilState = configuration.device.makeDepthStencilState(descriptor: dsd)!
        pipelineDesc.vertexDescriptor = self.vertexDescriptor;
        
    }
    public var screenSize:CGSize = CGSize(width: 320, height: 480)

    public var rectangle:[vertex] {
        let w:Float = Float(self.screenSize.width) / 10
        let h:Float = Float(self.screenSize.height) / 10
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
    public func render(image:CGImage,drawable:CAMetalDrawable,buffer:MTLCommandBuffer) throws{
        
        let text = try MTKTextureLoader.init(device: self.configuration.device).newTexture(cgImage: image, options: nil)
        try self.render(texture: text, drawable: drawable,buffer:buffer)
    }
    
    public func render(texture:MTLTexture,drawable:CAMetalDrawable,buffer:MTLCommandBuffer) throws{
        let renderPass = MTLRenderPassDescriptor()
        if(self.vertice == nil){
            self.vertice = self.configuration.device.makeBuffer(bytes: rectangle, length: MemoryLayout<vertex>.stride * rectangle.count, options: .storageModeShared)
        }
        renderPass.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
        renderPass.colorAttachments[0].storeAction = .store
        renderPass.colorAttachments[0].loadAction = .clear
        renderPass.colorAttachments[0].texture = drawable.texture
        renderPass.depthAttachment.clearDepth = 1
        renderPass.depthAttachment.texture = self.configuration.createDepthTexture(width: drawable.texture.width, height: drawable.texture.height)
        renderPass.stencilAttachment.clearStencil = 1
        renderPass.stencilAttachment.texture = renderPass.depthAttachment.texture
        guard let indexb = self.indexVertice else { return  }
        if self.pipelineState == nil{
            self.pipelineState = try configuration.device.makeRenderPipelineState(descriptor: self.pipelineDescriptor)
        }
        guard let encoder = buffer.makeRenderCommandEncoder(descriptor: renderPass) else { throw NSError(domain: "start encoder fail", code: 0, userInfo: nil)}
        if self.viewPort == nil{
            self.viewPort = MTLViewport(originX: 0, originY: 0, width: Double(self.screenSize.width), height: Double(self.screenSize.height)
                                  , znear: -1, zfar: 1)
        }
        self.matrix(x: 0, y: a, z: 0)
        a += 0.08
        encoder.setViewport(self.viewPort!)
        guard let pipelinestate = self.pipelineState else { encoder.endEncoding();return}
        encoder.setRenderPipelineState(pipelinestate)
        encoder.setVertexBuffer(self.vertice, offset: 0, index: 0)
        encoder.setVertexBytes(&self.worldState, length: MemoryLayout.stride(ofValue: self.worldState), index: 1)
        encoder.setDepthStencilState(self.depthStencilState)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentSamplerState(self.samplerState, index: 0)
        encoder.setCullMode(.none)
        encoder.drawIndexedPrimitives(type: .triangleStrip, indexCount: rectangleIndex.count, indexType: .uint32, indexBuffer: indexb, indexBufferOffset: 0)
        encoder.endEncoding()
        buffer.present(drawable)
    }
    public func matrix(x:Float,y:Float,z:Float){
        self.worldState.world = simd_float4x4.perspective(fov: .pi / 4, aspect: Float(self.screenSize.width / self.screenSize.height), near: 0.1, far: 10000) *
        simd_float4x4.camera(positionX: 0, positionY: 300, positionZ:  0, rotateX: -.pi / 16, rotateY: 0 , rotateZ:0) *
        simd_float4x4.translate(x: 0, y: 0, z: 1000) *
        simd_float4x4.rotate(x: x, y: y, z: z)
    }
}

extension simd_float4x4 {
    public static func perspective(fov:Float,aspect:Float,near:Float,far:Float) -> simd_float4x4{
        let range = near - far
        let tanhalf = tan(fov / 2.0)
        return simd_float4x4(rows: [
            [1.0 / (tanhalf * aspect),0,0,0],
            [0, 1.0 / tanhalf,0,0],
            [0,0,(-near - far) / range,2.0 * far * near / range],
            [0,0,1,0]
        ])
    }
    public static func rotate(x:Float,y:Float,z:Float)->simd_float4x4{
        let rotateY = simd_float4x4(rows: [
            [cos(y),0,sin(y),0],
            [0,1,0,0],
            [-sin(y),0,cos(y),0],
            [0,0,0,1],
        ])
        let rotateX = simd_float4x4(rows: [
            
            [1,0,0,0],
            [0,cos(x),-sin(x),0],
            [0,sin(x),cos(x),0],
            [0,0,0,1],
        ])
        let rotateZ = simd_float4x4(rows: [
            [cos(z),-sin(z),0,0],
            [sin(z),cos(z),0,0],
            [0,0,1,0],
            [0,0,0,1],
        ])
        return rotateX * rotateY * rotateZ
    }
    public static func translate(x:Float,y:Float,z:Float)->simd_float4x4{
        let translate = simd_float4x4(rows: [
            [1,0,0,x],
            [0,1,0,y],
            [0,0,1,z],
            [0,0,0,1],
        ])
        return translate
    }
    public static func scale(x:Float,y:Float,z:Float)->simd_float4x4{
        let scale = simd_float4x4(rows: [
            [x,0,0,0],
            [0,y,0,0],
            [0,0,z,0],
            [0,0,0,1],
        ])
        return scale
    }
    
    public static func camera(positionX:Float,
                              positionY:Float,
                              positionZ:Float,
                              rotateX:Float,rotateY:Float,rotateZ:Float)->simd_float4x4{
        self.rotate(x: rotateX, y: rotateY, z: rotateZ) * self.translate(x: -positionX, y: -positionY, z: -positionZ)
    }
}
