//
//  File.swift
//  CokeVideo
//
//  Created by hao yin on 2021/2/25.
//

import Metal
import MetalKit
import Foundation
import simd


public struct Point{
    public var x:Float
    public var y:Float
    public init(x:Float, y:Float){
        self.x = x
        self.y = y
    }
}
public struct Size{
    public var w:Float
    public var h:Float
    public init(w:Float, h:Float){
        self.w = w
        self.h = h
    }
}
public struct Rect{
    public var location:Point
    public var size:Size
    public init(x:Float,y:Float,w:Float,h:Float){
        self.location = Point(x:x,y:y)
        self.size = Size(w:w,h:h)
    }
}

public protocol CokeLayer{
    var frame:Rect { get set }
    var bound:Rect { get set }
    var zPosion:Float { get set }
    var backgroundColor:simd_float4 { get set }
    
    var pipelineDescriptor:MTLRenderPipelineDescriptor { get }
}

public struct vertex{
    public var location: simd_float4
    public var texture: simd_float2
    public init(location:simd_float4,texture:simd_float2){
        self.location = location
        self.texture = texture
    }
}

extension CokeLayer{
    public var vertice:[vertex]{
        let bound = UIScreen.main.bounds
        let x1 = self.frame.location.x / Float(bound.size.width)
        let y1 = self.frame.location.y / Float(bound.size.height)
        
        let w1 = self.frame.size.w / Float(bound.size.width)
        let h1 = self.frame.size.h / Float(bound.size.height)
        
        let v = [
            vertex(location: simd_float4(x: x1 - 1, y: y1 - 1, z: zPosion,w: 1), texture: simd_float2(x: 0, y: 0)),
            vertex(location: simd_float4(x: x1 - 1 + w1, y: y1 - 1, z: zPosion,w: 1), texture: simd_float2(x: 1, y: 0)),
            vertex(location: simd_float4(x: x1 - 1, y: y1 - 1 + h1, z: zPosion,w: 1), texture: simd_float2(x: 0, y: 1)),
            vertex(location: simd_float4(x: x1 - 1 + w1, y: y1 - 1 + h1, z: zPosion,w: 1), texture: simd_float2(x: 1, y: 1)),
        ]
        return v
    }
    public func verticsBuffer(device:MTLDevice)->MTLBuffer?{
        return device.makeBuffer(bytes: self.vertice, length: MemoryLayout<vertex>.stride * vertice.count, options: .storageModeShared)
    }
    
    public func indexVertice(device:MTLDevice)->MTLBuffer? {
        return device.makeBuffer(bytes: rectangleIndex, length: rectangleIndex.count * MemoryLayout<UInt32>.stride, options: .storageModeShared)
    }
    public var rectangleIndex:[UInt32]{
        [
            0,1,2,3
        ]
    }
}

public struct CokeView:CokeLayer{
    public var pipelineDescriptor: MTLRenderPipelineDescriptor
    
    public var frame: Rect
    
    public var bound: Rect
    
    public var zPosion: Float = 1
    
    public var backgroundColor: simd_float4 = simd_float4(x: 1, y: 1, z: 1, w: 1)
    
    public init(frame:Rect,configuration:CokeMetalConfiguration,vertex:String,fragment:String) {
        self.frame = frame
        bound = Rect(x: 0, y: 0, w: frame.size.w, h: frame.size.h)
        let pipelineDesc = MTLRenderPipelineDescriptor()
        pipelineDesc.vertexFunction = configuration.shaderLibrary.makeFunction(name: vertex)
        pipelineDesc.fragmentFunction = configuration.shaderLibrary.makeFunction(name: fragment)
        pipelineDesc.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
        self.pipelineDescriptor = pipelineDesc
    }
}

