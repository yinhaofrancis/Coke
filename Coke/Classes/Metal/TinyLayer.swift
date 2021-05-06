//
//  CokeLayer.swift
//  CokeVideo
//
//  Created by hao yin on 2021/3/24.
//

import Foundation


public enum BlendMode{
    case blendClear
    case blendSrc
    case blendDst
    case blendSrcOver
    case blendDstOver
    case blendSrcIn
    case blendDstIn
    case blendSrcOut
    case blendDstOut
    case blendSrcAtop
    case blendDstAtop
    case blendXor
}

public class Layer{
    public var blendMode:BlendMode
    public init(blendMode:BlendMode){
        self.blendMode = blendMode
    }
}
