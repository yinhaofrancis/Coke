//
//  TextRender.swift
//  Coke
//
//  Created by hao yin on 2021/5/14.
//

import Foundation
import CoreText
import QuartzCore

public class CokeContext{
    public typealias callback = (CGImage?)->Void
    public private(set) var context:CGContext
    private var queue:DispatchQueue = DispatchQueue(label: "CokeContext")
    public init(width:Int,height:Int) throws {
        let scale = UIScreen.main.scale
        guard let ctx = CGContext(data: nil, width: width * Int(scale), height: height * Int(scale), bitsPerComponent: 8, bytesPerRow: width * Int(scale) * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw NSError(domain: "error", code: 0, userInfo: nil)}
        self.context = ctx
        self.context.scaleBy(x: scale, y: scale)
    }
    public func draw(call:@escaping (CokeContext)->Void){
        self.queue.async {
            call(self)
        }
    }
    public func renderImage(result:@escaping callback){
        self.queue.async {
            let img = self.context.makeImage()
            RunLoop.main.perform(inModes: [.default]) {
                result(img)
            }
        }
        
    }
}

public protocol CokeAttributeContent{
    var size:CGSize { get }
}

public class CokeAttributeItem{
    public var content:CokeAttributeContent?
    public var size:CGSize?
    public var baseline:CGFloat = 0
    private var rundelegate:CTRunDelegate?
    public fileprivate(set) var frame:CGRect  = .zero
    public init(){
        var c = CTRunDelegateCallbacks(version: 0) { i in
            
        } getAscent: { i in
            let me = Unmanaged<CokeAttributeItem>.fromOpaque(i).takeUnretainedValue()
            guard let size = (me.size ?? me.content?.size) else { return 0 }
            return size.height - me.baseline
        } getDescent: { i in
            let me = Unmanaged<CokeAttributeItem>.fromOpaque(i).takeUnretainedValue()
            return me.baseline
        } getWidth: { i in
            let me = Unmanaged<CokeAttributeItem>.fromOpaque(i).takeUnretainedValue()
            guard let size = (me.size ?? me.content?.size) else { return 0 }
            return size.width
        }
        self.rundelegate = CTRunDelegateCreate(&c, Unmanaged.passUnretained(self).toOpaque())
    }
    public var attributeString:NSAttributedString{
        NSAttributedString(string: "0", attributes: [
            NSAttributedString.Key(kCTRunDelegateAttributeName as String):self.rundelegate as Any,
            .init("CokeAttributeItem"):self,
            .font:UIFont.systemFont(ofSize: 5),
            .foregroundColor:UIColor.clear
        ])
    }
    public func draw(context:CGContext,rect:CGRect){
        context.saveGState()
        context.setFillColor(UIColor.blue.cgColor)
        context.fill(rect)
        context.restoreGState()
    }
}

extension NSAttributedString{
    public func frame(ctx:CGContext,rect:CGRect)->CTFrame {
        let set = self.setter
        let frame = CTFramesetterCreateFrame(set, CFRange(location: 0, length: self.length), CGPath(rect: rect, transform: nil), nil)
        self.loadFrame(ctx: ctx, frame: frame,rect: rect)
        return frame
    }
    public var setter:CTFramesetter{
        CTFramesetterCreateWithAttributedString(self as CFAttributedString)
    }
    public func size(limit:CGSize)->CGSize{
        CTFramesetterSuggestFrameSizeWithConstraints(self.setter, CFRange(location: 0, length: self.length), nil, limit, nil)
    }
    public func loadFrame(ctx:CGContext,frame:CTFrame,rect:CGRect){
        
        guard let lines = CTFrameGetLines(frame) as? Array<CTLine> else { return }
        let points = UnsafeMutablePointer<CGPoint>.allocate(capacity: lines.count)
        CTFrameGetLineOrigins(frame, CFRangeMake(0, lines.count), points)
        for index in 0..<lines.count {
            let i = lines[index]
            guard let runs = CTLineGetGlyphRuns(i) as? Array<CTRun> else { return }
            for j in runs {
                guard let att = CTRunGetAttributes(j) as? Dictionary<String,Any> else { return }
                if((att["CokeAttributeItem"]) != nil){
                    guard let item = att["CokeAttributeItem"] as? CokeAttributeItem else { return }
                    var ascent:CGFloat = 0
                    var descent:CGFloat = 0
                    var leading:CGFloat = 0
                    let width = CTRunGetTypographicBounds(j, CFRangeMake(0, 1), &ascent, &descent, &leading)
                    var point = CGPoint.zero
                    CTRunGetPositions(j, CFRangeMake(0, 1), &point)
                    let origin = points.advanced(by: index).pointee
                    let p = CGPoint(x: rect.origin.x + origin.x + point.x, y: rect.origin.y + origin.y + point.y - descent)
                    let rect = CGRect(x: p.x, y: p.y, width: CGFloat(width), height: ascent + descent)
                    item.frame = rect
                    item.draw(context: ctx, rect: rect)
                }
            }
        }
        points.deallocate()
    }
}
