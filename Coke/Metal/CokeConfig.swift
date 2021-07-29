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
    #if targetEnvironment(simulator)
    public static let metalColorFormat:MTLPixelFormat = .bgra8Unorm
    public static let videoColorFormat:UInt32 = kCVPixelFormatType_32BGRA
    #else
    public static let metalColorFormat:MTLPixelFormat = .bgra8Unorm_srgb
    public static let videoColorFormat:UInt32 = kCVPixelFormatType_32BGRA
    #endif
    
}
