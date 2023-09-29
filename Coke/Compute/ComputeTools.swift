//
//  ComputeTools.swift
//  Coke
//
//  Created by wenyang on 2023/9/28.
//

import Foundation
import Accelerate
import AudioToolbox

public struct ComputeTools{
    public class fft{
        let ctx:vDSP.FFT<DSPSplitComplex>?
        public init(){
            ctx = vDSP.FFT(log2n: 10, radix: .radix5, ofType: DSPSplitComplex.self)
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

extension Data{
    public func list<T>(type:T.Type)->[T]{
        self.withUnsafeBytes { $0.withMemoryRebound(to: type.self){$0}.map{$0} }
    }
    public func pointer<T>(type:T.Type)->UnsafeBufferPointer<T>{
        self.withUnsafeBytes{$0.withMemoryRebound(to: type){$0}}
    }
    public func rawPointer()->UnsafeRawBufferPointer{
        self.withUnsafeBytes {$0}
    }
    public mutating func mutablePointer<T>(type:T.Type)->UnsafeMutableBufferPointer<T>{
        self.withUnsafeMutableBytes {$0.withMemoryRebound(to: type) {$0}}
    }
    public mutating func mutableRawPointer()->UnsafeMutableRawBufferPointer{
        self.withUnsafeMutableBytes {$0}
    }
    public func complex(description:AudioStreamBasicDescription)->([Float],[Float]){
        let time = Double(description.mBytesPerFrame) / Double(description.mSampleRate)
        let sampleCount = self.count / Int(description.mBytesPerFrame)
        let timeOffset = time / Double(sampleCount)
        let times:[Float] = (0 ..< sampleCount).reduce(into: []) { partialResult, i in
            if partialResult.count == 0{
                partialResult.append(0)
            }else{
                partialResult.append(partialResult.last! + Float(timeOffset))
            }
        }
        return (times,self.list(type: Float.self))
    }
}
