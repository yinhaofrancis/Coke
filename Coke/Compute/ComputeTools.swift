//
//  ComputeTools.swift
//  Coke
//
//  Created by wenyang on 2023/9/28.
//

import Foundation
import Accelerate


public struct ComputeTools{
    public class fft{
        let ctx:vDSP.FFT<DSPSplitComplex>?
        public init(log2n:vDSP_Length){
            ctx = vDSP.FFT(log2n: log2n, radix: .radix5, ofType: DSPSplitComplex.self)
        }
        @discardableResult
        public func complex(realp:inout [Float],
                            imagp: inout [Float],
                            orealp:inout [Float],
                            oimagp:inout [Float],
                            callback:(DSPSplitComplex,inout DSPSplitComplex)->Void)->Bool{
            if(realp.count == 1024 && imagp.count == 1024){
                realp.withUnsafeMutableBufferPointer { r in
                    imagp.withUnsafeMutableBufferPointer { i in
                        let inp = DSPSplitComplex(realp: r.baseAddress!, imagp: i.baseAddress!)
                        orealp.withUnsafeMutableBufferPointer { or in
                            oimagp.withUnsafeMutableBufferPointer { oi in
                                var outp = DSPSplitComplex(realp: or.baseAddress!, imagp: oi.baseAddress!)
                                callback(inp,&outp)
                            }
                        }
                    }
                }
                return true
            }
            return false
        }
        
        public func forward(realp:inout [Float],
                        imagp: inout [Float],
                        orealp:inout [Float],
                        oimagp:inout [Float]){
            self.complex(realp: &realp, imagp: &imagp, orealp: &orealp, oimagp: &oimagp) { inv, ouv in
                ctx?.forward(input: inv, output: &ouv)
            }
        }
        public func inverse(realp:inout [Float],
                               imagp: inout [Float],
                               orealp:inout [Float],
                               oimagp:inout [Float]){
            self.complex(realp: &realp, imagp: &imagp, orealp: &orealp, oimagp: &oimagp) { inv, ouv in
                ctx?.inverse(input: inv, output: &ouv)
            }
        }
    }
}
