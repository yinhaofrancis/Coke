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

public let ShaderVertexBufferIndex = 0

public let ShaderVertexWorldMatrixIndex = 1

public let ShaderVertexCameraMatrixIndex = 2

public let ShaderFragmentLightingIndex = 3

public let ShaderFragmentDiffuseTextureIndex = 0

public let ShaderFragmentSpecularTextureIndex = 1

public let ShaderFragmentSamplerIndex = 0

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
    var inverse:simd_float4x4
    public init(mat: simd_float4x4) {
        self.mat = mat
        self.inverse = mat.inverse
    }
};

public struct WorldTransformUniform{
    var world:simd_float4x4
    var camera:simd_float4x4
};

public struct LightingUniform{
    var type:Int
    var ambient:simd_float3
    var diffuse:simd_float3
    var specular:simd_float3
    var lightPos:simd_float3
    var lightDir:simd_float3
    var specularStrength:Float
    var viewPos:simd_float3
    var shininess:Float
    var constantValue:Float
    var linear:Float
    var quadratic:Float
    var cutOff:Float

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
    
    public func makeTextureFrom(cgimage:CGImage) ->MTLTexture?{
        try? MTKTextureLoader(device: self.device).newTexture(cgImage: cgimage)
    }
    public func makeTextureFrom(data:Data)->MTLTexture?{
        try? MTKTextureLoader(device: self.device).newTexture(data: data)
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

    private var renderDepthTarget:MTLTexture?
    
    private var colorTexture:MTLTexture?
    
    public var currentRenderPassDescription:MTLRenderPassDescriptor{
 
        let renderPassDescription = self._renderPassDescription
        self.currentDrawable = self.layer.nextDrawable()
        if(colorTexture == nil){
            self.colorTexture = self.currentDrawable?.texture
        }
        let colorTexture = self.colorTexture
        if renderDepthTarget == nil{
            let depthStenci = self.render.createDepthTexture(width: colorTexture!.width, height: colorTexture!.height)
            self.renderDepthTarget = depthStenci
        }else{
            if(renderDepthTarget!.width != colorTexture!.width || renderDepthTarget!.height != colorTexture!.height){
                let depthStenci = self.render.createDepthTexture(width: colorTexture!.width, height: colorTexture!.height)
                self.renderDepthTarget = depthStenci
            }
        }
       
        renderPassDescription.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
        renderPassDescription.colorAttachments[0].loadAction = .clear
        renderPassDescription.colorAttachments[0].storeAction = .store
        renderPassDescription.colorAttachments[0].texture = self.currentDrawable?.texture
        
        
        renderPassDescription.depthAttachment.clearDepth = 1;
        renderPassDescription.depthAttachment.texture = self.renderDepthTarget
        renderPassDescription.depthAttachment.loadAction = .clear
        renderPassDescription.depthAttachment.storeAction = .store
        renderPassDescription.stencilAttachment.clearStencil = 1
        renderPassDescription.stencilAttachment.texture = self.renderDepthTarget
        renderPassDescription.stencilAttachment.loadAction = .clear
        renderPassDescription.stencilAttachment.storeAction = .store
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
    func render(encoder:MTLRenderCommandEncoder)
}


public class CokeBoxModel:CokeModel{
    
    public var translate:simd_float3 = [0,0,0]
    
    public var scale:simd_float3 = [1,1,1]
    
    public var rotate:simd_float3 = [0,0,0]
    
    public var mtkMesh:MTKMesh?
    
    private var diff:MTLTexture
    
    private var specular:MTLTexture
    
    private var sampleState:MTLSamplerState?
    
    private var renderPipline:MTLRenderPipelineState
    
    private var world:TransformUniform {
        let v = TransformUniform(
            mat: simd_float4x4.translate(x: self.translate.x, y: self.translate.y, z: self.translate.z) *
            simd_float4x4.scale(x: self.scale.x, y: self.scale.y, z: self.scale.z) *
            simd_float4x4.rotate(x: self.rotate.x, y: self.rotate.y, z: self.rotate.z))
        return v
    }
    
    public init(render: CokeModelRender,diff:String,specular:String) throws {
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
        self.diff = render.makeTextureFrom(data: UIImage(named: diff)!.pngData()!)!
        self.specular = render.makeTextureFrom(data: UIImage(named: specular)!.pngData()!)!
        let sample = MTLSamplerDescriptor()
        sample.mipFilter = .linear
        sample.magFilter = .linear
        sample.minFilter = .linear
        self.sampleState = render.device.makeSamplerState(descriptor: sample)
        self.genetate(device: render.device)
    }
    

    func genetate(device:MTLDevice){
        let md = MDLMesh(boxWithExtent: [1,1,1], segments: [1,1,1], inwardNormals: false, geometryType: .triangles, allocator: MTKMeshBufferAllocator(device: device))
//        let md = MDLMesh(sphereWithExtent: [1,1,1], segments: [20,20], inwardNormals: false, geometryType: .triangles, allocator: MTKMeshBufferAllocator(device: device))

        let mk = try! MTKMesh(mesh: md, device: device)
        self.mtkMesh = mk
    }
    
    
    public func render(encoder: MTLRenderCommandEncoder) {
        encoder.setRenderPipelineState(self.renderPipline)
        encoder.setCullMode(.none)
        var w = world
        guard let mesh = self.mtkMesh else {
            return
        }
        encoder.setVertexBuffer(mesh.vertexBuffers[0].buffer, offset: 0, index: ShaderVertexBufferIndex)
        encoder.setVertexBytes(&w, length: MemoryLayout<TransformUniform>.size, index: ShaderVertexWorldMatrixIndex)
        encoder.setFragmentTexture(self.diff, index: ShaderFragmentDiffuseTextureIndex)
        encoder.setFragmentTexture(self.specular, index: ShaderFragmentSpecularTextureIndex)
        encoder.setFragmentSamplerState(self.sampleState,index: ShaderFragmentSamplerIndex)
        for i in mesh.submeshes{
            encoder.drawIndexedPrimitives(type: i.primitiveType, indexCount: i.indexCount, indexType: i.indexType, indexBuffer: i.indexBuffer.buffer, indexBufferOffset: i.indexBuffer.offset)
        }
        
    }
}

public struct CokeCamera{
    public var camera:simd_float4x4
    public var perspective:simd_float4x4
    public init(camera:simd_float4x4,perspective:simd_float4x4) {
        self.camera = camera
        self.perspective = perspective
    }
    public var matrix:TransformUniform {
        TransformUniform(
            mat:perspective * camera)
    }
}

public enum LightType:Int{
    case directlight = 0
    case spotlight = 1
}

public struct CokeLighting {
    public var ambient:simd_float3
    public var diffuse:simd_float3
    public var specular:simd_float3
    public var lightPos:simd_float3
    public var lightDir:simd_float3
    public var specularStrength:Float
    public var viewPos:simd_float3
    public var shininess:Float
    public var type:LightType
    public var constantValue:Float
    public var linear: Float
    public var quadratic: Float
    public var cutOff:Float
    public var LightingUniform:LightingUniform{
        return Coke.LightingUniform(
            type: type.rawValue,
            ambient: self.ambient,
            diffuse: self.diffuse,
            specular: self.specular,
            lightPos: self.lightPos, lightDir: lightDir,
            specularStrength: self.specularStrength,
            viewPos: self.viewPos,
            shininess: self.shininess,
            constantValue: constantValue,
            linear: linear,
            quadratic: quadratic,
            cutOff: 12.5
        )
    }
}

public struct CokeScene{
    
    public var camera:TransformUniform{
        TransformUniform(
            mat:simd_float4x4.perspective(fov: .pi / 4, aspect: self.aspect, near: 0.1, far: 10000) * simd_float4x4.camera(positionX: self.cameraPos.x, positionY: self.cameraPos.y, positionZ: self.cameraPos.z, rotateX: self.cameraRotate.x, rotateY: self.cameraRotate.y, rotateZ: self.cameraRotate.z))
    }
    
    public var lighting:LightingUniform{
        LightingUniform(
            type: 0,
            ambient: [0.3,0.3,0.3],
            diffuse: [0.8,0.8,0.8],
            specular: [1,1,1],
            lightPos: lightPos,
            lightDir: self.lightDir,
            specularStrength: 0.8,
            viewPos: self.cameraPos,
            shininess: 8,
            constantValue: 1,
            linear: 0.09,
            quadratic: 0.032,
            cutOff: 12.5)
    }
    public var cameraPos:simd_float3
    public var cameraRotate:simd_float3
    public var aspect:Float
    public var lightPos:simd_float3
    public var lightDir:simd_float3
    public weak var render:CokeModelRender?
    
    public init(position:simd_float3,cameraRotate:simd_float3,lightPos:simd_float3,lightDir:simd_float3 = [0,0,0],aspect:Float) {
        self.cameraPos = position
        self.aspect = aspect
        self.lightDir = lightDir
        self.cameraRotate = cameraRotate
        self.lightPos = lightPos
    }
    public func encoder(encoder:MTLRenderCommandEncoder){
        var c = self.camera
        encoder.setVertexBytes(&c, length: MemoryLayout<TransformUniform>.stride, index: ShaderVertexCameraMatrixIndex)
        var l = self.lighting
        encoder.setFragmentBytes(&l, length: MemoryLayout<LightingUniform>.stride, index: ShaderFragmentLightingIndex)
    }
}
