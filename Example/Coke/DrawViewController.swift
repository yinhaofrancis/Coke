//
//  DrawViewController.swift
//  Coke_Example
//
//  Created by hao yin on 2021/5/17.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import UIKit
import Coke
class DrawViewController: UIViewController {

    @IBOutlet weak var back : BackgroundRenderView!
    override func viewDidLoad() {
        super.viewDidLoad()
        let b = NSMutableAttributedString()
            
        let a1 = CokeAttributeItem()
        a1.size = CGSize(width: 44, height: 44)
        a1.backgroundColor = UIColor.orange.cgColor
        a1.fillMode = .normal
        a1.shadowBlur = 3
        b.append(a1.attributeString)
        
        let a2 = CokeAttributeItem()
        a2.size = CGSize(width: 44, height: 44)
        a2.fillMode = .fillParent
        b.append(a2.attributeString)
        
        let a3 = CokeAttributeItem()
        a3.backgroundColor = UIColor.orange.cgColor
        a3.size = CGSize(width: 44, height: 44)
        a3.fillMode = .normal
        b.append(a3.attributeString)
        
        
        
        let b1 = NSMutableAttributedString()
        let a4 = CokeAttributeItem()
        a4.size = CGSize(width: 44, height: 44)
        a4.backgroundColor = UIColor.yellow.cgColor
        a4.fillMode = .fillParent
        b1.append(a4.attributeString)
        
        let a5 = CokeAttributeItem()
        a5.backgroundColor = UIColor.green.cgColor
        a5.fillMode = .normal
        let p = NSMutableParagraphStyle()
        p.lineSpacing = 0
        p.paragraphSpacing = 0
        p.paragraphSpacingBefore = 0
        p.alignment = .center
        p.minimumLineHeight = 44
        let a = NSAttributedString(string: "Title", attributes: [
                            .font:UIFont.systemFont(ofSize: 20),
                    .foregroundColor:UIColor.black,
            .paragraphStyle:p
        ])
        a5.content = a
        b1.append(a5.attributeString)
        
        let a6 = CokeAttributeItem()
        a6.backgroundColor = UIColor.red.cgColor
        a6.size = CGSize(width: 44, height: 44)
        a6.fillMode = .fillParent
        b1.append(a6.attributeString)
        a2.content = b1
        let sum = CokeAttributeItem()
        sum.fillMode = .fillParent
        sum.shadowBlur = 6
        sum.content = b
        sum.shadowColor = UIColor.black.cgColor
        let bt = UIButton(type: .system)
        bt.setTitle("Frame", for: .normal)
        self.back.addSubview(bt)
        a1.content = bt
        a1.backgroundColor = UIColor.lightGray.cgColor
        self.back.item = sum
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { i in
            self.back.item = sum
        })
        
        
    }
    var timer:Timer?

}
