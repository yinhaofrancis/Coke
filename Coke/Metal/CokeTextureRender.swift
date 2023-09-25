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
        dsd.depthCompareFunction = .less
        dsd.isDepthWriteEnabled = true;
        self.depthStencilDescriptor = dsd
        self.pipelineDescriptor = pipelineDesc
        self.depthStencilState = configuration.device.makeDepthStencilState(descriptor: dsd)!
        pipelineDesc.vertexDescriptor = self.vertexDescriptor;
        
    }
    public var screenSize:CGSize = CGSize(width: 320, height: 480)

    public var rectangle:[vertex] {
        let w:Float = Float(self.screenSize.width / 2)
        let h:Float = Float(self.screenSize.height / 2)
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
            self.matrix(x: Float(self.screenSize.width), y: Float(self.screenSize.height), z: 1)
        }
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
        self.worldState.world = simd_float4x4.orthographic(bottom: -y / 2, top: y / 2, left: -x / 2, right: x / 2, near: 0, far: z);
    }
}


public struct Coke2DVertex{
    public var location:simd_float2
    public var texturevx:simd_float2?
    public var color:simd_float4
    public init(location: simd_float2, texturevx: simd_float2? = nil, color: simd_float4) {
        self.location = location
        self.texturevx = texturevx
        self.color = color
    }
    public var vertexDescription:MTLVertexDescriptor{
        if texturevx == nil{
            let mv = MTLVertexDescriptor()
            mv.attributes[0].format = .float2
            mv.attributes[0].offset = 0;
            mv.attributes[0].bufferIndex = 0
            mv.attributes[1].format = .float4
            mv.attributes[1].offset = 8
            mv.attributes[1].bufferIndex = 0
            mv.layouts[0].stepRate = 1;
            mv.layouts[0].stepFunction = .perVertex
            mv.layouts[0].stride = 24
            return mv
        }else{
            let mv = MTLVertexDescriptor()
            mv.attributes[0].format = .float2
            mv.attributes[0].offset = 0;
            mv.attributes[0].bufferIndex = 0
            mv.attributes[1].format = .float2
            mv.attributes[1].offset = 8
            mv.attributes[1].bufferIndex = 0
            
            mv.attributes[2].format = .float4
            mv.attributes[2].offset = 16
            mv.attributes[2].bufferIndex = 0
            mv.layouts[0].stepRate = 1;
            mv.layouts[0].stepFunction = .perVertex
            mv.layouts[0].stride = 32
            return mv
        }
        
    }
    public var vertex:[Float]{
        if let texturevx {
            return [self.location.x,self.location.y,texturevx.x,texturevx.y,color.x,color.y,color.z,color.w]
        }else{
            return [self.location.x,self.location.y,color.x,color.y,color.z,color.w]
        }
        
    }
}
public struct Coke2DPath{
    public var vertex:[Coke2DVertex]
    public var index:[UInt32] = []
    public var plain:[Float]{
        self.vertex.flatMap{$0.vertex}
    }
    public static func triangle(coke:Coke2D,
                                point1:simd_float2,
                                point2:simd_float2,
                                point3:simd_float2,
                                color:simd_float4)throws ->Coke2DPath{
        return try Coke2DPath(coke: coke, vertex: [
            Coke2DVertex(location: point1, color: color),
            Coke2DVertex(location: point2, color: color),
            Coke2DVertex(location: point3, color: color),
        ])
    }
    public init(coke:Coke2D,vertex:[Coke2DVertex]) throws{
        let desc = MTLRenderPipelineDescriptor()
        self.vertex = vertex
        desc.colorAttachments[0].pixelFormat = .bgra8Unorm
        desc.depthAttachmentPixelFormat = .depth32Float_stencil8;
        desc.stencilAttachmentPixelFormat = .depth32Float_stencil8
        desc.vertexFunction = coke.shaderLibrary?.makeFunction(name: "coke2dvertex")
        desc.fragmentFunction = coke.shaderLibrary?.makeFunction(name: "coke2dfragment")
        desc.vertexDescriptor = vertex.first?.vertexDescription
        desc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        desc.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        desc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        desc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        desc.colorAttachments[0].isBlendingEnabled = true
        desc.colorAttachments[0].rgbBlendOperation = .add
        desc.colorAttachments[0].alphaBlendOperation = .add
        self.state = try coke.device.makeRenderPipelineState(descriptor: desc)
    }
    
    public var state:MTLRenderPipelineState
    
    public func draw(encode:MTLRenderCommandEncoder){
        encode.setRenderPipelineState(self.state)
        let p = self.plain
        encode.setVertexBytes(p, length: p.count * MemoryLayout<Float>.size, index: 0)
        encode.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: self.vertex.count)
    }
}
public class Coke2D{
    public var device:MTLDevice
    public var commandQueue:MTLCommandQueue
    public var depthStencil:MTLTexture
    public var renderPassDescription:MTLRenderPassDescriptor
    public var shaderLibrary:MTLLibrary?
    public private(set) var layer:CAMetalLayer
    private func loadDefaultLibrary() throws{
        self.shaderLibrary = try self.device.makeDefaultLibrary(bundle: Bundle(for: CokeComputer.self))
    }
    static let scale = 3
    private var width:Int
    private var height:Int
    public init(w:UInt32,h:UInt32) throws {
        self.width = Int(w) * Coke2D.scale
        self.height = Int(h) * Coke2D.scale
        let device = try Coke2D.createDevice();
        self.device = device
        self.commandQueue = try Coke2D.createCommandQueue(device: device)
        self.depthStencil = try Coke2D.createTexture(w: self.width, h: self.height, pixelFormat: .depth32Float_stencil8, device: device)
        self.renderPassDescription = MTLRenderPassDescriptor()
        renderPassDescription.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
        renderPassDescription.colorAttachments[0].loadAction = .clear
        renderPassDescription.colorAttachments[0].storeAction = .store
        renderPassDescription.depthAttachment.clearDepth = 1;
        renderPassDescription.depthAttachment.texture = self.depthStencil
        renderPassDescription.depthAttachment.loadAction = .clear
        renderPassDescription.depthAttachment.storeAction = .store
        renderPassDescription.stencilAttachment.clearStencil = 1;
        renderPassDescription.stencilAttachment.texture = self.depthStencil
        renderPassDescription.stencilAttachment.loadAction = .clear
        renderPassDescription.stencilAttachment.storeAction = .store
        self.layer = CAMetalLayer()
        self.layer.frame = CGRect(x: 0, y: 0, width: Int(w), height: Int(h))
        self.layer.contentsScale = CGFloat(Coke2D.scale);
        try self.loadDefaultLibrary()
    }
    
    public func createCommandBuffer() throws ->MTLCommandBuffer{
        guard let buffer = self.commandQueue.makeCommandBuffer() else { throw NSError(domain: "fail create command buffer", code: 5, userInfo: nil)}
        return buffer
    }
    
    public func draw(call:(MTLRenderCommandEncoder)->Void) throws{
        let buffer = try self.createCommandBuffer()
        guard let drawable = self.layer.nextDrawable() else { return }
        self.renderPassDescription.colorAttachments[0].texture = drawable.texture
        guard let encoder = buffer.makeRenderCommandEncoder(descriptor: self.renderPassDescription) else {
            throw NSError(domain: "fail create encoder", code: 6)
        }
        encoder.setViewport(MTLViewport(originX: 0, originY: 0, width: Double(self.width), height: Double(self.height), znear: -1, zfar: 1))
        var mat = simd_float4x4.orthographic(bottom: Float(self.height / -2), top: Float(self.height / 2), left: Float(self.width / -2), right: Float(self.width / 2), near: -1, far: 1)
        encoder.setVertexBytes(&mat, length: MemoryLayout.size(ofValue: mat), index: 1)
        call(encoder)
        encoder.endEncoding()
        buffer.present(drawable)
        buffer.commit()
        buffer.waitUntilCompleted()
    }
    
    
    
    
    
    public static func createDevice() throws ->MTLDevice{
        guard let d = MTLCreateSystemDefaultDevice() else { throw NSError(domain: "fail create device", code: 0, userInfo: nil)}
        return d
    }
    
    public static func createTexture(w:Int,h:Int,pixelFormat:MTLPixelFormat,device:MTLDevice) throws ->MTLTexture{
        let d = MTLTextureDescriptor()
        d.width = w;
        d.height = h;
        d.usage = [.renderTarget,.shaderRead,.shaderWrite]
        d.storageMode = .shared
        d.textureType = .type2D
        d.pixelFormat = pixelFormat
        guard let texture = device.makeTexture(descriptor: d) else { throw NSError(domain: "create texture fail", code: 1, userInfo: nil)  }
        return texture
    }
    
    public static func createCommandQueue(device:MTLDevice) throws -> MTLCommandQueue{
        guard let queue = device.makeCommandQueue() else { throw NSError(domain: "create queue fail", code: 3)}
        return queue
    }
}
