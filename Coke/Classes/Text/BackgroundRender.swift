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
    func size(limit:CGSize)->CGSize
    func draw(context:CGContext,rect:CGRect)
}
public enum FillMode{
    case fillParent
    case normal
}
public class CokeAttributeItem{
    
    public var contentSize: CGSize{
        let w = self.size?.width ?? 0  + self.extra
        let h = self.size?.height ?? 0
        return CGSize(width: w, height: h)
    }
    
    public var fillMode:FillMode = .normal
    public var content:CokeAttributeContent?
    public var size:CGSize?
    public var extra:CGFloat = 0
    public var baseline:CGFloat = 0
    public var backgroundColor:CGColor = UIColor.white.cgColor
    public var shadowOffset:CGSize = .zero
    public var shadowBlur:CGFloat = 0
    public var shadowColor:CGColor?
    
    private var rundelegate:CTRunDelegate?
    public fileprivate(set) var frame:CGRect  = .zero
    public init(){
        var c = CTRunDelegateCallbacks(version: 0) { i in
            
        } getAscent: { i in
            let me = Unmanaged<CokeAttributeItem>.fromOpaque(i).takeUnretainedValue()
            guard let size = (me.size ?? me.content?.size(limit: me.size ?? .zero)) else { return 0 }
            return size.height - me.baseline
        } getDescent: { i in
            let me = Unmanaged<CokeAttributeItem>.fromOpaque(i).takeUnretainedValue()
            return me.baseline
        } getWidth: { i in
            let me = Unmanaged<CokeAttributeItem>.fromOpaque(i).takeUnretainedValue()
            guard let size = (me.size ?? me.content?.size(limit: me.size ?? .zero)) else { return 0 }
            return size.width + me.extra
        }
        self.rundelegate = CTRunDelegateCreate(&c, Unmanaged.passUnretained(self).toOpaque())
    }
    public var attributeString:NSAttributedString{
        let p = NSMutableParagraphStyle()
        p.lineSpacing = 0
        p.paragraphSpacing = 0
        p.paragraphSpacingBefore = 0
        return NSAttributedString(string: "\u{FFFC}", attributes: [
            NSAttributedString.Key(kCTRunDelegateAttributeName as String):self.rundelegate as Any,
            .init("CokeAttributeItem"):self,
            .font:UIFont.systemFont(ofSize: 5),
            .foregroundColor:UIColor.clear,
            .paragraphStyle:p
        ])
    }
    public func draw(context:CGContext,rect:CGRect){
        context.saveGState()
        context.setShadow(offset: self.shadowOffset, blur: self.shadowBlur, color: self.shadowColor)
        context.setFillColor(self.backgroundColor)
        context.fill(rect)
        context.restoreGState()
    }
}

extension NSAttributedString:CokeAttributeContent{
    public func frame(ctx:CGContext,rect:CGRect)->CTFrame {
        let set = self.setter
        let frame = CTFramesetterCreateFrame(set, CFRange(location: 0, length: self.length), CGPath(rect: rect, transform: nil), nil)
        self.loadFrameFill(frame: frame, rect: rect)
        return CTFramesetterCreateFrame(set, CFRange(location: 0, length: self.length), CGPath(rect: rect, transform: nil), nil)
    }
    public var setter:CTFramesetter{
        CTFramesetterCreateWithAttributedString(self as CFAttributedString)
    }
    public func size(limit:CGSize)->CGSize{
        let size = CGSize(width: limit.width <= 0 ? CGFloat.infinity : limit.width, height: limit.height <= 0 ? CGFloat.infinity : limit.height)
        return CTFramesetterSuggestFrameSizeWithConstraints(self.setter, CFRange(location: 0, length: self.length), nil, size, nil)
    }
    public func draw(context:CGContext,rect:CGRect){
        let frame = self.frame(ctx: context, rect: rect)
        self.drawFrame(ctx: context, frame: frame, rect: rect)
    }
    public func drawFrame(ctx:CGContext,frame:CTFrame,rect:CGRect){
        CTFrameDraw(frame, ctx)
        guard let lines = CTFrameGetLines(frame) as? Array<CTLine> else { return }
        let points = UnsafeMutablePointer<CGPoint>.allocate(capacity: lines.count)
        CTFrameGetLineOrigins(frame, CFRangeMake(0, lines.count), points)
        
        for index in 0..<lines.count {
            let i = lines[index]
            guard let runs = CTLineGetGlyphRuns(i) as? Array<CTRun> else { return }
            
            for jindex in 0 ..< runs.count {
                let j = runs[jindex]
                guard let att = CTRunGetAttributes(j) as? Dictionary<String,Any> else { return }
                if((att["CokeAttributeItem"]) != nil){
                    guard let item = att["CokeAttributeItem"] as? CokeAttributeItem else { return }
                    var ascent:CGFloat = 0
                    var descent:CGFloat = 0
                    var leading:CGFloat = 0
                    let width = CTRunGetTypographicBounds(j, CFRangeMake(0, 0), &ascent, &descent, &leading)
         
                    let rpoints = UnsafeMutablePointer<CGPoint>.allocate(capacity: runs.count)
                    let count = CTRunGetGlyphCount(j)
                    CTRunGetPositions(j, CFRangeMake(0,0), rpoints)
                    let origin = points.advanced(by: index).pointee
                    
                    for runIndex in 0 ..< count{
                        let point = rpoints.advanced(by: runIndex).pointee
                        let p = CGPoint(x: rect.origin.x + origin.x + point.x, y: rect.origin.y + origin.y + point.y - descent)
                        let rect = CGRect(x: p.x, y: p.y, width: CGFloat(width), height: ascent + descent)
                        item.draw(context: ctx, rect: rect)
                        item.extra = 0
                        if let content = item.content {
                            content.draw(context: ctx, rect: rect)
                            
                        }
                    }
                    rpoints.deallocate()
                }
            }
        }
        points.deallocate()
    }
    
    public func loadFrameFill(frame:CTFrame,rect:CGRect){
        
        guard let lines = CTFrameGetLines(frame) as? Array<CTLine> else { return }
        let points = UnsafeMutablePointer<CGPoint>.allocate(capacity: lines.count)
        CTFrameGetLineOrigins(frame, CFRangeMake(0, lines.count), points)
        
        for index in 0..<lines.count {
            let i = lines[index]
            let extrasum = rect.width - CGFloat(CTLineGetTypographicBounds(i, nil, nil, nil))
            
            guard let runs = CTLineGetGlyphRuns(i) as? Array<CTRun> else { return }
            let items = runs.filter { run in
                guard let att = CTRunGetAttributes(run) as? Dictionary<String,Any> else { return false }
                if((att["CokeAttributeItem"]) is CokeAttributeItem){
                    return true
                }else{
                    return false
                }
            }.filter { run in
                let att = CTRunGetAttributes(run) as! Dictionary<String,Any>
                let item = att["CokeAttributeItem"] as! CokeAttributeItem
                return item.fillMode == .fillParent
            }.map { run -> CokeAttributeItem in
                let att = CTRunGetAttributes(run) as! Dictionary<String,Any>
                let item = att["CokeAttributeItem"] as! CokeAttributeItem
                return item
            }
            let extrac = items.reduce(0) { l, c in
                l + (c.fillMode == .fillParent ? 1 : 0)
            }
            if extrac > 0{
                for i in items{
                    i.extra = CGFloat(extrasum) / CGFloat(extrac)
                }
            }
        }
        points.deallocate()
    }
}
extension UIButton:CokeAttributeContent{
    public func size(limit: CGSize) -> CGSize {
        self.sizeThatFits(limit)
    }
    
    public func draw(context: CGContext, rect: CGRect) {
        RunLoop.main.perform(inModes: [.default]) {
            self.frame = self.translateCoodinate(container: self.superview?.frame ?? .zero, frame: rect)
        }
    }
}
extension CokeAttributeContent{
    func translateCoodinate(container:CGRect,frame:CGRect) -> CGRect{
        return frame.applying(CGAffineTransform(scaleX: 1, y: -1).concatenating(CGAffineTransform(translationX: 0, y: container.height)))
        
    }
}
