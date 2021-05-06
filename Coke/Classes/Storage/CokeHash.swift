//
//  CokeHash.swift
//  PEMTVideo
//
//  Created by hao yin on 2020/11/26.
//

import Foundation
import CommonCrypto


public typealias CC = (_ data: UnsafeRawPointer, _ len: CC_LONG, _ md: UnsafeMutablePointer<UInt8>) -> UnsafeMutablePointer<UInt8>


public struct CokeHash {
    public static func SHA256(data:Data)->Data{
        let call:CC = {
            CC_SHA256($0, $1, $2)
        }
        return Hash(data: data, digest: Int(CC_SHA256_DIGEST_LENGTH), cFunc: call)
    }
    public static func md5(data:Data)->Data{
        let call:CC = {
            CC_MD5($0, $1, $2)
        }
        return Hash(data: data, digest: Int(CC_MD5_DIGEST_LENGTH), cFunc: call)
    }
    public static func SHA1(data:Data)->Data{
        let call:CC = {
            CC_SHA1($0, $1, $2)
        }
        return Hash(data: data, digest: Int(CC_SHA1_DIGEST_LENGTH), cFunc: call)
    }
    public static func SHA512(data:Data)->Data{
        let call:CC = {
            CC_SHA512($0, $1, $2)
        }
        return Hash(data: data, digest: Int(CC_SHA512_DIGEST_LENGTH), cFunc: call)
    }
    
    public static func SHA384(data:Data)->Data{
        let call:CC = {
            CC_SHA384($0, $1, $2)
        }
        return Hash(data: data, digest: Int(CC_SHA384_DIGEST_LENGTH), cFunc: call)
    }
    public static func SHA224(data:Data)->Data{
        let call:CC = {
            CC_SHA224($0, $1, $2)
        }
        return Hash(data: data, digest: Int(CC_SHA224_DIGEST_LENGTH), cFunc: call)
    }
    public static func Hash(data:Data,digest:Int,cFunc:CC)->Data{
        let p:UnsafeMutablePointer<UInt8> = UnsafeMutablePointer.allocate(capacity: data.count)
        let result = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(digest))
        data.copyBytes(to: p, count: data.count)
        _ = cFunc(p, CC_LONG(data.count), result)
        let rdata = Data(bytes: result, count: digest)
        p.deallocate()
        result.deallocate()
        return rdata
    }
}


extension Data{
    public var hexString:String{
        self.map{String(format: "%02x", $0)}.reduce("", {$0+$1})
    }
}
