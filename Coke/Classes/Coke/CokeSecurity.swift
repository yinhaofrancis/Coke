//
//  CokeSecurity.swift
//  Coke_Example
//
//  Created by hao yin on 2021/5/6.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import Foundation
import Security
import CommonCrypto
import LocalAuthentication

open class CokeKey{
    public enum KeyType{
        case RSA
        case EC
    }
    public enum KeyClass{
        case Public
        case Private
    }
    let key:SecKey
    let type:KeyType
    let cls:KeyClass
    let size:Int
    public init(key:SecKey,cls:KeyClass,type:KeyType,size:Int) {
        self.key = key
        self.type = type
        self.size = size
        self.cls = cls
    }
    public var keyData:Data?{
        return SecKeyCopyExternalRepresentation(self.key, nil) as Data?
    }
    public static func generatePair(type:KeyType,size:Int) throws ->(CokePublicKey,CokePrivateKey){
        var strTy = kSecAttrKeyTypeRSA
        switch type {
        case .RSA:
            strTy = kSecAttrKeyTypeRSA
        case .EC:
            strTy = kSecAttrKeyTypeECSECPrimeRandom
        }
        let a = [kSecAttrKeyType: strTy,
                 kSecAttrKeySizeInBits: size] as [CFString : Any]
        var privateKey:SecKey?
        var publicKey:SecKey?
        if errSecSuccess == SecKeyGeneratePair(a as CFDictionary, &publicKey, &privateKey){
            let pk = CokePublicKey(key: publicKey!, type: type, size: size)
            let pr = CokePrivateKey(key: privateKey!, type: type, size: size)
            return (pk,pr)
        }else{
            throw NSError(domain: "fail", code: 0, userInfo: nil)
        }
    }
    public init(key:String,cls:KeyClass,type:KeyType,size:Int) throws {
        guard let dat = Data(base64Encoded: key) as CFData? else{
            throw NSError(domain: "is not base64 Data", code: 0, userInfo: nil)
        }
        var strcls = kSecAttrKeyClassPublic
        switch cls {
        case .Public:
            strcls = kSecAttrKeyClassPublic
            break
        case .Private:
            strcls = kSecAttrKeyClassPrivate
            break
        }
        var e:Unmanaged<CFError>?
        let a = [kSecAttrKeyType: type,
                 kSecAttrKeyClass: strcls,
                 kSecAttrKeySizeInBits: size] as [CFString : Any]
        guard let seckey = SecKeyCreateWithData(dat, a as CFDictionary, &e) else {
            let estr = "error \(String(describing: e!.takeRetainedValue()))"
            throw NSError(domain: estr, code: 0, userInfo: nil)
        }
        self.cls = cls
        self.key = seckey
        self.type = type
        self.size = size
    }
}

public class CokePublicKey:CokeKey{
    
    public init(publicKey:String,type:KeyType,size:Int) throws{
        try super.init(key: publicKey, cls: .Public, type: type, size: size)
    }
    public init(key: SecKey, type: KeyType, size: Int) {
        super.init(key: key, cls: .Public, type: type, size: size)
    }
    
    public func encrypt(padding:SecPadding = .init(rawValue: 0),data:Data)->Data?{
        let blockSize = SecKeyGetBlockSize(self.key)

        let maxChunkSize = (padding == .init(rawValue: 0)) ? blockSize : blockSize - 11
        let datap = UnsafeMutablePointer<UInt8>.allocate(capacity: maxChunkSize)
        
        
        let plain = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
        data.copyBytes(to: plain, count: data.count)
        var len = 0
        
        
        
        let state = SecKeyEncrypt(self.key, padding, plain, data.count, datap, &len)
        plain.deallocate()
        if errSecSuccess == state{
           
            return Data(bytesNoCopy: datap, count: len, deallocator: .free)
        }
        return nil
    }
    
}
public class CokePrivateKey:CokeKey{
    public init(key: SecKey, type: KeyType, size: Int) {
        super.init(key: key, cls: .Private, type: type, size: size)
    }
    public func decrypt(padding:SecPadding = .init(rawValue: 0),data:Data)->Data?{
        let datap = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)

        data.copyBytes(to: datap, count: data.count)
        let plain = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)

        var c:Int = 0
        datap.deallocate()
        let state = SecKeyDecrypt(self.key, padding, datap, data.count, plain, &c)
        if errSecSuccess == state {
            return Data(bytesNoCopy: plain, count: c, deallocator: .free)
        }
       return nil
    }
}

extension Data{
    public var base64ToBase64url:String {
        let base64 = self.base64EncodedString()
        let base64url = base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return base64url
    }
}
extension String{
    public var base64ToBase64url:String {
        guard let a = self.data(using: .utf8) else { return "" }
        return a.base64ToBase64url
    }
}
