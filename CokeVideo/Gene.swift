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

public struct Gene:Codable{
    public var values:[Float] = []
    public var score:Double = 0
    public func path(coke:Coke2D) throws ->Coke2DPath {
        return try Coke2DPath(coke: coke, value: self.values, vertexCount: self.values.count / 6, vertexDescriptor: Coke2DVertex(location: [0,0], texturevx: nil, color: [0,0,0,0]).vertexDescription)
    }
    public init(count:Int = 150 * 3 * 6) {
        self.values = (0..<count).map({ i in
            Float.random(in: -1 ... 1)
        })
    }
    public mutating func draw(coke:Coke2D,texture:MTLTexture) throws{
        let path = try self.path(coke: coke)
        let buffer = try coke.begin();
        try coke.drawInto(buffer: buffer, texture: texture) { e in
            path.draw(encode: e)
        }
        try coke.draw(buffer: buffer, texture: texture)
        coke.commit(buffer: buffer)
    }
    public func mutations(count:Int)->Gene{
        var g = self
        let loopCount = count < 1 ? 1 : count
        for _ in 0 ..< loopCount{
            let randv = Float.random(in: -1 ... 1)
            let randi = Int.random(in: 0 ..< self.values.count)
            g.values[randi] = randv;
        }
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
    public var random:Int = 4
    public var filterSource:MTLTexture
    lazy var texture = try! coke.createTexture(w: coke.width, h: coke.height)
    lazy var out = try! coke.createTexture(w: coke.width, h: coke.height)
    private var diff:ComputeDiff
    private var sum:ComputeSum
    public init(count:Int,coke:Coke2D,filterSource:CGImage,ngens:[Gene] = []) throws{
        self.coke = coke
        self.filterSource = try coke.loader.newTexture(cgImage: filterSource)
        self.sum = try ComputeSum(coke: coke)
        self.diff = try ComputeDiff(coke: coke, cg: filterSource, type: .hamming)
        if ngens.count > 0{
            self.gens = ngens
        }else{
            gens = (0 ..< count).map({ i in
                var g = Gene()
                try! self.filter(gene: &g)
                return g
            })
        }
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
//        for _ in 0 ..< 20 {
//            var ges:[Gene] = []
//            for i in 0 ..< ges.count{
//                if gens[i].score < 0.0001{
//                    try self.filter(gene: &gens[i]);
//                }
//                ges.append(gens[i])
//            }
//            for i in 0 ..< self.gens.count{
//                var new = self.gens[i].mutations(count: 5)
//                try self.filter(gene: &new);
//                ges.append(new)
//                
//                let randi = Int.random(in: 0 ..< self.gens.count)
//                var new2 = self.gens[i].exchange(gen: self.gens[randi])
//                try self.filter(gene: &new2);
//                ges.append(new2)
//            }
//            ges.sort { a, b in
//                a.score < b.score
//            }
//            while(ges.count > self.gens.count || ges.count > 60){
//                let a = ges.removeLast()
//                if #available(iOS 14.0, *) {
//                    os_log("\(a.score)")
//                } else {
//                    // Fallback on earlier versions
//                }
//            }
//            self.gens = ges;
//        }
//        let data = try JSONEncoder().encode(self.gens)
//        if #available(iOS 16.0, *) {
//            let u = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appending(path: "data.json")
//            try data.write(to: u);
//        } else {
//            // Fallback on earlier versions
//        }
//        ges.sort { a, b in
//            a.score < b.score
//        }
//        while ges.count > 60 {
//            let a = ges.removeLast()
//            
//            if #available(iOS 14.0, *) {
//                os_log("coke __ remove \(a.score)")
//            } else {
//                // Fallback on earlier versions
//            }
//        }
//        self.gens = ges
        
    }
    public static func parse(coke:Coke2D,filterSource:CGImage) ->Population{
        do{
            if #available(iOS 16.0, *) {
                let u = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appending(path: "data.json")
                let data = try Data(contentsOf: u)
                let gem = try JSONDecoder().decode([Gene].self, from: data)
                return try Population(count: gem.count, coke: coke, filterSource: filterSource,ngens: gem)
            } else {
                return try! Population(count: 60, coke: coke, filterSource: filterSource)
            }
        }catch{
            return try! Population(count: 60, coke: coke, filterSource: filterSource)
        }
        
    }
}
