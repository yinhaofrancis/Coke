//
//  ppm.swift
//  Coke
//
//  Created by wenyang on 2023/9/2.
//

import Foundation
import QuartzCore



@available(iOS 13.4, *)
public struct Ppm{
    public enum PpmType:Int{
        case bitmap = 1
        case graymap = 2
        case pixmap = 3
        public var maxPixelComponent:String{
            switch self{
                
            case .bitmap:
                return ""
            case .graymap:
                return "15"
            case .pixmap:
                return "255"
            }
        }
    }
    public var type:PpmType
    public var width:Int
    public var height:Int
    public var pixels:[UInt32]
    public init(type:PpmType,width:Int,height:Int,pixels:[UInt32]){
        self.type = type
        self.width = width
        self.height = height
        self.pixels = pixels
    }
    public var header:String{
        
        return "P\(type.rawValue) \(width) \(height) \(self.type.maxPixelComponent)"
    }
    
    public func write(url:URL){
        
        do{
            let fh = try FileHandle(forWritingTo: url)
            try fh.write(contentsOf: self.header.data(using: .utf8)!)
            for i in pixels{
                try fh.write(contentsOf: " \(i)".data(using: .utf8)!)
            }
            try fh.close()
        }catch{
            print(error)
        }
    }
}
