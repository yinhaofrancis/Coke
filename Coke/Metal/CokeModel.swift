//
//  CokeModel.swift
//  Coke
//
//  Created by wenyang on 2023/9/16.
//

import Metal
import MetalKit
import MetalFX
import simd

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
    public static let identity:simd_float4x4 = {
        return simd_float4x4(rows: [
            [1,0,0,0],
            [0,1,0,0],
            [0,0,1,0],
            [0,0,0,1]
        ])
    }()
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
public struct TransformUniform{
    var mat:simd_float4x4
};


public class CokeModelRender{
    public let device:MTLDevice
    public let queue:MTLCommandQueue
    public var depthStencilDescriptor = {
        let d = MTLDepthStencilDescriptor()
        d.depthCompareFunction = .lessEqual
        d.isDepthWriteEnabled = true
        return d
    }()
    public var depthStencilState:MTLDepthStencilState?
    
    public var library:MTLLibrary
    
    public init(librayUrl:URL? = nil) throws{
        guard let device = MTLCreateSystemDefaultDevice() else { throw NSError(domain: "not support Metal", code: 0)}
        if let url = librayUrl{
            self.library = try device.makeLibrary(URL: url)
        }else{
            self.library = try device.makeDefaultLibrary(bundle: Bundle(for: CokeModelRender.self))
        }
        guard let queue = device.makeCommandQueue(maxCommandBufferCount: 3) else { throw NSError(domain: "not support Metal", code: 0) }
        self.queue = queue
        self.device = device
    }
    
    public func createTexture(
        width:Int,
        height:Int,
        pixelformat:MTLPixelFormat = .bgra8Unorm,
        usage:MTLTextureUsage =  [.shaderRead,.shaderWrite],
        store:MTLStorageMode = .shared)->MTLTexture?{
        let d = MTLTextureDescriptor()
        d.pixelFormat = pixelformat
        d.width = width
        d.storageMode = store
        d.usage = usage
        d.height = height
        return self.device.makeTexture(descriptor: d)
    }
    public func createDepthTexture(
        width:Int,
        height:Int,
        pixelformat:MTLPixelFormat = .depth32Float_stencil8)->MTLTexture?{
        let d = MTLTextureDescriptor()
        d.pixelFormat = pixelformat
        d.width = width
        d.storageMode = .private
        d.usage = .renderTarget
        d.height = height
        return self.device.makeTexture(descriptor: d)
    }
    
    public func render(display:CokeRenderDisplay,renderCallBack:RenderCallBack){
        let buffer = self.queue.makeCommandBuffer()
        let currentRenderPass = display.currentRenderPassDescription
        guard let drawable = display.currentDrawable else {
            return
        }
        guard let encoder = buffer?.makeRenderCommandEncoder(descriptor: currentRenderPass) else { return }
        encoder.setViewport(display.viewPort)
        if self.depthStencilState == nil{
            self.depthStencilState = self.device.makeDepthStencilState(descriptor: self.depthStencilDescriptor)
        }
        guard let depthStencilState else { return }
        encoder.setDepthStencilState(depthStencilState)
        renderCallBack(encoder)
        encoder.endEncoding()
        buffer?.present(drawable)
        buffer?.commit()
        buffer?.waitUntilCompleted()
    }
    public func newRenderPipelineDesciptor()->MTLRenderPipelineDescriptor{
        let desc = MTLRenderPipelineDescriptor()
        desc.colorAttachments[0].pixelFormat = .bgra8Unorm
        desc.depthAttachmentPixelFormat = .depth32Float_stencil8
        desc.stencilAttachmentPixelFormat = .depth32Float_stencil8
        return desc
    }
    
    
    public typealias RenderCallBack = (MTLRenderCommandEncoder)->Void
    
}

public protocol CokeRenderDisplay{
    var currentRenderPassDescription:MTLRenderPassDescriptor { get }
    var viewPort:MTLViewport { get }
    var currentDrawable:CAMetalDrawable? { get }
}

public class CokeModelRenderDisplay:CokeRenderDisplay{
    
    public let render:CokeModelRender
    
    public let layer:CAMetalLayer
    
    public private(set) var currentDrawable:CAMetalDrawable?
    
    public init(render:CokeModelRender,layer:CAMetalLayer) {
        self.render = render
        self.layer = layer
        self.layer.pixelFormat = .bgra8Unorm
    }
    private var _renderPassDescription:MTLRenderPassDescriptor = MTLRenderPassDescriptor()

    public var currentRenderPassDescription:MTLRenderPassDescriptor{
        let renderPassDescription = self._renderPassDescription
        self.currentDrawable = self.layer.nextDrawable()
        let colorTexture = self.currentDrawable?.texture
        let depthStenci = self.render.createDepthTexture(width: colorTexture!.width, height: colorTexture!.height)
        renderPassDescription.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
        renderPassDescription.colorAttachments[0].loadAction = .clear
        renderPassDescription.colorAttachments[0].storeAction = .store
        renderPassDescription.colorAttachments[0].texture = self.currentDrawable?.texture
        
        
        renderPassDescription.depthAttachment.clearDepth = 1;
        renderPassDescription.depthAttachment.texture = depthStenci

        renderPassDescription.stencilAttachment.clearStencil = 1
        renderPassDescription.stencilAttachment.texture = depthStenci

        return renderPassDescription
    }
    
    public var viewPort:MTLViewport{
        MTLViewport(originX: 0, originY: 0, width: self.layer.frame.width, height: self.layer.frame.height, znear: -1, zfar: 1)
    }
}

public class CokeModelView:UIView{
    public override class var layerClass: AnyClass{
        return CAMetalLayer.self
    }
    public var display:CokeRenderDisplay?
    
    public var render:CokeModelRender?{
        didSet{
            guard let render else {
                self.display = nil;
                return
            }
            self.display = CokeModelRenderDisplay(render:render, layer: self.layer as! CAMetalLayer)
        }
    }
    
    public init(render:CokeModelRender){
        super.init(frame: .zero)
        self.render = render
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}


public protocol CokeModel{
    init(render:CokeModelRender) throws
    func render(encoder:MTLRenderCommandEncoder)
}

public struct Vertex:ExpressibleByArrayLiteral{
    public init(arrayLiteral elements: Float...) {
        var b:[Float] = [0,0,0,0,0,0,0,0]
        for i in 0 ..< elements.count{
            b[i] = elements[i]
        }
        vertics = simd_float3(b[0 ..< 3]);
        normal = simd_float3(b[3 ..< 6])
        texture = simd_float2(b[6 ..< 8])
    }
    
    public typealias ArrayLiteralElement = Float
    
    var vertics:simd_float3
    var normal:simd_float3
    var texture:simd_float2
}

public class CokeTriangleModel:CokeModel{
    
    private var value:Float = 0
    public var renderPipline:MTLRenderPipelineState
    var world:TransformUniform {
        let v = TransformUniform(mat: simd_float4x4.translate(x: 0, y: 0, z: 0) *  simd_float4x4.scale(x: 2, y: 2, z: 2) * simd_float4x4.rotate(x: 0, y: value, z: 0))
        value += 0.05
        return v
    }
    var camera:TransformUniform {
        TransformUniform(mat:simd_float4x4.perspective(fov: .pi / 4, aspect: Float(x), near: 0.1, far: 10000) * simd_float4x4.camera(positionX: 0, positionY: 20, positionZ: -30, rotateX: -0.5, rotateY: 0, rotateZ: 0))
    }
    private var texture:MTLTexture
    public var sampleState:MTLSamplerState?
    public var mtkMesh:MTKMesh?
    public required init(render: CokeModelRender) throws {
        let ct = render.library.makeFunction(name: "cokeTriagle")
        let fg = render.library.makeFunction(name: "cokeTriagleFragment")
        let desc = render.newRenderPipelineDesciptor()
        desc.fragmentFunction = fg
        desc.vertexFunction = ct
        
        let vd = MTLVertexDescriptor()
        vd.attributes[0].format = .float3
        vd.attributes[0].offset = 0
        vd.attributes[0].bufferIndex = 0
        vd.attributes[1].format = .float3
        vd.attributes[1].offset = 12
        vd.attributes[1].bufferIndex = 0
        vd.attributes[2].format = .float2
        vd.attributes[2].offset = 24
        vd.attributes[2].bufferIndex = 0
        vd.layouts[0].stride = 32
        vd.layouts[0].stepRate = 1
        vd.layouts[0].stepFunction = .perVertex
        desc.vertexDescriptor = vd
        self.renderPipline = try render.device.makeRenderPipelineState(descriptor: desc)
        self.texture = try MTKTextureLoader(device: render.device).newTexture(cgImage: UIImage(named: "a")!.cgImage!)
        let sample = MTLSamplerDescriptor()
        sample.mipFilter = .linear
        sample.magFilter = .linear
        sample.minFilter = .linear
        self.sampleState = render.device.makeSamplerState(descriptor: sample)
        self.genetate(device: render.device)
    }
    
    
    
    func genetate(device:MTLDevice){
        let md = MDLMesh(sphereWithExtent: [1,1,1], segments: [69,69], inwardNormals: false, geometryType: .triangles, allocator: MTKMeshBufferAllocator(device: device))
        let mk = try! MTKMesh(mesh: md, device: device)
        self.mtkMesh = mk
    }
    
    
    public func render(encoder: MTLRenderCommandEncoder) {
        encoder.setRenderPipelineState(self.renderPipline)
        encoder.setCullMode(.none)
        var w = world
        var c = camera
        guard let mesh = self.mtkMesh else {
            return
        }
        
        encoder.setVertexBuffer(mesh.vertexBuffers[0].buffer, offset: 0, index: 0)
        encoder.setVertexBytes(&w, length: MemoryLayout<TransformUniform>.size, index: 1)
        encoder.setVertexBytes(&c, length: MemoryLayout<TransformUniform>.size, index: 2)
        encoder.setFragmentTexture(self.texture, index: 0)
        encoder.setFragmentSamplerState(self.sampleState,index: 0)
        for i in mesh.submeshes{
            encoder.drawIndexedPrimitives(type: i.primitiveType, indexCount: i.indexCount, indexType: i.indexType, indexBuffer: i.indexBuffer.buffer, indexBufferOffset: i.indexBuffer.offset)
        }
        
    }
}

let x = UIScreen.main.bounds.width / UIScreen.main.bounds.height
