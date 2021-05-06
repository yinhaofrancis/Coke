//
//  CokeText.swift
//  CokeVideo_Example
//
//  Created by hao yin on 2021/3/12.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import Foundation
import UIKit
import CoreText

public struct CokeTextTypographicBounds{
    public var ascent:CGFloat
    public var descent:CGFloat
    public var leading:CGFloat
    public var width:CGFloat
    public var height:CGFloat{
        return ascent + descent
    }
}

public class CokeTextRun{
    public let run:CTRun
    public init(run:CTRun){
        self.run = run
    }
    public var typographicBounds:CokeTextTypographicBounds{
        var ascent:CGFloat = 0
        var descent:CGFloat = 0
        var leading:CGFloat = 0
        let w = CTRunGetTypographicBounds(self.run, CFRangeMake(0, 0), &ascent, &descent, &leading)
        
        return CokeTextTypographicBounds(ascent: ascent, descent: descent, leading: leading, width: CGFloat(w))
    }
    public var attribute:Dictionary<String,Any>{
        return CTRunGetAttributes(self.run) as! Dictionary<String,Any>
    }
}
public class CokeTextLine{
    public let line:CTLine
    public let runs:[CokeTextRun]
    public convenience init(string:CFAttributedString){
        self.init(line:CTLineCreateWithAttributedString(string))
    }
    public init(line:CTLine){
        self.line = line
        self.runs = ((CTLineGetGlyphRuns(line) as? [CTRun]) ?? []).map {CokeTextRun(run: $0)}
    }
    public var typographicBounds:CokeTextTypographicBounds{
        var a:CGFloat = 0
        var d:CGFloat = 0
        var l:CGFloat = 0
        let w = CTLineGetTypographicBounds(self.line, &a, &d, &l)
        return CokeTextTypographicBounds(ascent: a, descent: d, leading: l,width: CGFloat(w))
    }
}

public class CokeTextFrame{
    public let frame:CTFrame
    public let lines:[CokeTextLine]
    public var runs:[CokeTextRun]{
        var a:[CokeTextRun] = []
        for i in lines {
            a += i.runs
        }
        return a
    }
    public init(frame:CTFrame){
        self.frame = frame
        self.lines = ((CTFrameGetLines(frame) as? [CTLine]) ?? []).map{CokeTextLine(line: $0)}
    }
    public convenience init(string:CFAttributedString,range:CFRange,path:CGPath) {
        let frameset = CTFramesetterCreateWithAttributedString(string)
        let frame = CTFramesetterCreateFrame(frameset, range, path, nil)
        self.init(frame:frame)
    }
    public var lineBounds:[CGRect]{
        
        let point = UnsafeMutablePointer<CGPoint>.allocate(capacity: lines.count)
        CTFrameGetLineOrigins(self.frame, CFRangeMake(0, 0), point)
        let rects = (0..<lines.count).map { (i) -> CGRect in
            let frameLocation = CTFrameGetPath(self.frame).boundingBoxOfPath.origin;
            let lineLocation = point.advanced(by: i).pointee
            let bounds = lines[i].typographicBounds
            return CGRect(origin: CGPoint(x: frameLocation.x + lineLocation.x, y: frameLocation.y + lineLocation.y - bounds.descent), size: CGSize(width: bounds.width, height: bounds.height))
        }
        point.deallocate()
        return rects
    }
    public var linePoint:[CGPoint]{
        
        let point = UnsafeMutablePointer<CGPoint>.allocate(capacity: lines.count)
        CTFrameGetLineOrigins(self.frame, CFRangeMake(0, 0), point)
        let points = (0..<lines.count).map { (i) -> CGPoint in
            return point.advanced(by: i).pointee
        }
        point.deallocate()
        return points
    }
    public var runBounds:[CGRect]{
        var rects:[CGRect] = []
        for i in 0 ..< self.lines.count {
            let p = self.linePoint[i]
            for j in 0 ..< self.lines[i].runs.count{
                let x = p.x + CTLineGetOffsetForStringIndex(self.lines[i].line, CTRunGetStringRange(self.lines[i].runs[j].run).location, nil) + self.bound.minX
                let s = self.lines[i].runs[j].typographicBounds
                let y = p.y - s.descent + self.bound.minY
                let r = CGRect(x: x, y: y, width: s.width, height: s.height)
                rects.append(r)
            }
        }
        return rects
    }
    public var bound:CGRect{
        CTFrameGetPath(self.frame).boundingBoxOfPath
    }
    public func draw(ctx:CGContext){
        let rb = self.runBounds
        CTFrameDraw(self.frame, ctx)
        let runs = self.runs
        for i in (0 ..< runs.count) {
            if let p = runs[i].attribute["CokeRunProtocol"] as? CokeRunProtocol {
                p.draw(rect: rb[i], ctx: ctx)
            }
        }
    }
}
public protocol CokeRunProtocol{
    var ascent:CGFloat { get set }

    var descent:CGFloat { get set }
    
    var width:CGFloat { get set }
    
    var runDelegate:CTRunDelegate { get }
    
    func draw(rect:CGRect,ctx:CGContext)
}
public class CokeRunDelegate:CokeRunProtocol{
    public func draw(rect: CGRect, ctx: CGContext) {
        ctx.saveGState()
        ctx.setFillColor(UIColor.orange.cgColor)
        ctx.fill(rect)
        ctx.restoreGState()
    }
    
    public class Info{
        var delegate:CokeRunDelegate
        init(delegate:CokeRunDelegate) {
            self.delegate = delegate
        }
    }
    
    
    public var ascent:CGFloat

    public var descent:CGFloat
    

    private var info:CokeRunDelegate.Info?
    public var width:CGFloat
    
    public init(ascent:CGFloat,descent:CGFloat,width:CGFloat){
        self.ascent = ascent
        self.descent = descent
        self.width = width
    }
    
    public lazy var runDelegate:CTRunDelegate = {
        
        var ck = CTRunDelegateCallbacks(version: 0) { (v) in
            var p = v.assumingMemoryBound(to: CokeRunDelegate.Info.self)
            p.pointee.delegate.info = nil
        } getAscent: { (s) -> CGFloat in

            var p = s.assumingMemoryBound(to: CokeRunDelegate.Info.self)
            return p.pointee.delegate.ascent
        } getDescent: { (s) -> CGFloat in
            let d = s.assumingMemoryBound(to: CokeRunDelegate.Info.self).pointee
            return d.delegate.descent
        } getWidth: { (s) -> CGFloat in
            let d = s.assumingMemoryBound(to: CokeRunDelegate.Info.self).pointee
            return d.delegate.width
        }
//        var cp = UnsafeMutablePointer<CokeRunDelegate.Info>.allocate(capacity: 1)
        var d = CokeRunDelegate.Info(delegate: self)

        self.info = d
        return CTRunDelegateCreate(&ck, &self.info)!
    }()
}
public enum CokeContentMode{
    case scaleToFill
    case scaleToAcceptFit
    case scaleToAcceptFill
}

public class CokeTextImage:CokeRunDelegate{
    public let image:CGImage

    public var contentMode:CokeContentMode = .scaleToFill
    public init(image:CGImage,font:CTFont) {
        self.image = image
        super.init(ascent: CTFontGetAscent(font), descent: CTFontGetDescent(font), width: CTFontGetSize(font))
    }
    public override func draw(rect: CGRect, ctx: CGContext) {
        let astiox = rect.width / CGFloat(self.image.width)
        let astioy = rect.height / CGFloat(self.image.height)
        
        switch self.contentMode {
        
        case .scaleToFill:
            ctx.draw(self.image, in: rect)
            break
        case .scaleToAcceptFit:
            let r = min(astiox, astioy)
            let size = CGSize(width: r * CGFloat(self.image.width), height: r * CGFloat(self.image.height))
            let position = CGPoint(x: rect.minX + (rect.width - size.width) / 2, y: rect.minY + (rect.height - size.height) / 2)
            ctx.draw(self.image, in: CGRect(origin: position, size: size))
            break
        case .scaleToAcceptFill:
            let r = max(astiox, astioy)
            let size = CGSize(width: r * CGFloat(self.image.width), height: r * CGFloat(self.image.height))
            let position = CGPoint(x: rect.minX + (rect.width - size.width) / 2, y: rect.minY + (rect.height - size.height) / 2)
            ctx.saveGState()
            ctx.addRect(rect)
            ctx.clip()
            ctx.draw(self.image, in: CGRect(origin: position, size: size))
            ctx.restoreGState()
            break
        }
        
    }
}

extension NSAttributedString{
    public class func runDelegate(run:CokeRunProtocol)->NSAttributedString{
        
        return NSAttributedString(string: "0", attributes:
                                    [
                                        .foregroundColor:UIColor.clear,
                                        NSAttributedString.Key(kCTRunDelegateAttributeName as String):run.runDelegate,
                                        NSAttributedString.Key("CokeRunProtocol"):run])
    }
}
