//
//  Gene.swift
//  CokeVideo
//
//  Created by hao yin on 2023/9/26.
//

import Foundation
import Coke
import Metal
import CoreGraphics
import os

public struct Gene{
    public var values:[Float] = []
    public var score:Double = 0
    public func path(coke:Coke2D) throws ->Coke2DPath {
        return try Coke2DPath(coke: coke, value: self.values, vertexCount: self.values.count / 6, vertexDescriptor: Coke2DVertex(location: [0,0], texturevx: nil, color: [0,0,0,0]).vertexDescription)
    }
    public init(count:Int = 20 * 3 * 6) {
        self.values = (0..<count).map({ i in
            Float.random(in: -1 ... 1)
        })
    }
    public func draw(coke:Coke2D) throws{
        let texture = try coke.createTexture(w: coke.width, h: coke.height)
        let path = try self.path(coke: coke)
        let buffer = try coke.begin();
        try coke.drawInto(buffer: buffer, texture: texture) { e in
            path.draw(encode: e)
        }
        try coke.draw(buffer: buffer, texture: texture)
        coke.commit(buffer: buffer)
    }
    public func mutations()->Gene{
        var g = self
        let randv = Float.random(in: -1 ... 1)
        let randi = Int.random(in: 0 ..< self.values.count)
        g.values[randi] = randv;
        return g
    }
    public func exchange(gen:Gene)->Gene{
        var g = self
        for i in 0 ..< gen.values.count{
            if(Bool.random()){
                g.values[i] = gen.values[i];
            }
        }
        return g
    }
}

public class Population{
    public var gens:[Gene] = []
    public var coke:Coke2D
    public var filterSource:MTLTexture
    lazy var texture = try! coke.createTexture(w: coke.width, h: coke.height)
    lazy var out = try! coke.createTexture(w: coke.width, h: coke.height)
    private var diff:ComputeDiff
    private var sum:ComputeSum
    public init(count:Int,coke:Coke2D,filterSource:CGImage) throws{
        self.coke = coke
        self.filterSource = try coke.loader.newTexture(cgImage: filterSource)
        self.sum = try ComputeSum(coke: coke)
        self.diff = try ComputeDiff(coke: coke, cg: filterSource, type: .hamming)
        gens = (0 ..< count).map({ i in
            var g = Gene()
            try! self.filter(gene: &g)
            return g
        })
    }
    public func filter(gene:inout Gene) throws{
        let path = try gene.path(coke: coke)
        let buffer = try coke.begin();
        try coke.drawInto(buffer: buffer, texture: texture) { e in
            path.draw(encode: e)
        }
        
        diff.origin = texture;
        diff.diff = self.filterSource
        diff.out = out
        sum.texture = out
        try coke.compute(buffer: buffer) { e in
            diff.compute(encoder: e, coke: coke)
            sum.compute(encoder: e, coke: coke)
        }
        coke.commit(buffer: buffer)
        gene.score = Double(sum.sum)
    }
    public func filter() throws{        
        for _ in 0 ..< 20 {
            var ges = self.gens
            for i in 0 ..< self.gens.count{
                if(Int.random(in: 0 ..< 10) < 4){
                    var new = self.gens[i].mutations()
                    try self.filter(gene: &new);
                    ges.append(new)
                }
                let randi = Int.random(in: 0 ..< self.gens.count)
                var new = self.gens[i].exchange(gen: self.gens[randi])
                try self.filter(gene: &new);
                ges.append(new)
            }
            ges.sort { a, b in
                a.score < b.score
            }
            while(ges.count > self.gens.count){
                let a = ges.removeLast()
                if #available(iOS 14.0, *) {
                    os_log("\(a.score)")
                } else {
                    // Fallback on earlier versions
                }
            }
            self.gens = ges;
        }
        
    }
}
