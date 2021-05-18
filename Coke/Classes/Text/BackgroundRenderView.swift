//
//  BackgroundRenderView.swift
//  Coke
//
//  Created by hao yin on 2021/5/17.
//

import UIKit

open class BackgroundRenderView: UIView {
    var ctx:CokeContext?{
        didSet{
            if (self.ctx == nil){
                self.drawItem()
            }
        }
    }
    open override func layoutSubviews() {
        super.layoutSubviews()
        self.ctx = nil
        print(self.bounds,self.frame)
    }
    private func drawItem(){
        if ctx == nil{
            self.ctx = try? CokeContext(width: Int(self.frame.width), height: Int(self.frame.height))
        }
        let bounds = self.bounds
        self.ctx?.draw(call: {[weak self] c in
            guard let ws = self else { return }
            c.context.setFillColor(UIColor.white.cgColor)
            c.context.fill(bounds)
            ws.item?.attributeString.draw(context: c.context, rect:bounds)
        })
        self.ctx?.renderImage(result: { [weak self] i in
            guard let ws = self else { return }
            let u = UIImage(cgImage: i!)
            print(u)
            ws.layer.contents = i
        })
    }
    open var item:CokeAttributeItem?{
        didSet{
            self.drawItem()
        }
    }
}
