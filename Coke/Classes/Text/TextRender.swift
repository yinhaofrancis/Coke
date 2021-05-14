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
    public private(set) var context:CGContext?
    private var result:callback
    public init(width:Int,height:Int,result:@escaping callback){
        let scale = UIScreen.main.scale
        self.result = result
        self.context = CGContext(data: nil, width: width * Int(scale), height: height * Int(scale), bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
        self.context?.scaleBy(x: scale, y: scale)
    }
    public func draw(call:@escaping (CokeContext)->Void){
        DispatchQueue.global().async {
            call(self)
            RunLoop.main.perform(inModes: [.default]) {
                self.result(self.context?.makeImage())
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
            NSAttributedString.Key(kCTRunDelegateAttributeName as String):self,
            .font:UIFont.systemFont(ofSize: 5),
            .foregroundColor:UIColor.clear
        ])
    }
}

public class CokeAttributeString:NSMutableAttributedString{
    public func frame(rect:CGRect)->CTFrame {
        let set = self.setter
        return CTFramesetterCreateFrame(set, CFRange(location: 0, length: self.length), CGPath(rect: rect, transform: nil), nil)
    }
    public var setter:CTFramesetter{
        CTFramesetterCreateWithAttributedString(self as CFAttributedString)
    }
    public func size(limit:CGSize)->CGSize{
        CTFramesetterSuggestFrameSizeWithConstraints(self.setter, CFRange(location: 0, length: self.length), nil, limit, nil)
    }
}
