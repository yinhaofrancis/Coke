//
//  CokeConfig.swift
//  Coke
//
//  Created by wenyang on 2021/7/30.
//

import Foundation
import Metal
import CoreVideo
import MetalKit
public struct CokeConfig{
    public static let metalColorFormat:MTLPixelFormat = .bgra8Unorm
    public static let videoColorFormat:UInt32 = kCVPixelFormatType_32BGRA
}
