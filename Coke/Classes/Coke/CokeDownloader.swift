//
//  WebSourceDownloader.swift
//  WebSource
//
//  Created by hao yin on 2021/4/30.
//

import Foundation

public class CokeSessionDownloader{
    
    public var storage:CokeStorage
    public let url:URL
    public var group = DispatchGroup()
    var page:UInt64 = 1024 * 1024 * 20
    public init(url:URL) throws{
        self.url = url
     
        guard let dic = CokeDiskStorage.cacheDictionary else {
            throw NSError(domain: "save dir create fail", code: 0, userInfo: nil)
        }
        guard let name = CokeDiskStorage.digest(name: url.absoluteString) else {
            throw NSError(domain: "digest name fail", code: 0, userInfo: nil)
        }
        self.storage = try CokeDiskStorage(dir: dic, identify: name)
        self.storage.dataHeader.status = 0
        print(self.storage)
    }
    public var count:UInt64{
        UInt64(ceil(Float(self.storage.size) / Float(self.page)))
    }
    private func range(indx:UInt64)->ClosedRange<UInt64>?{
        let range = indx * page ... (indx + 1) * page - 1
        return self .checkRange(range: range)
    }
    private func checkRange(range:ClosedRange<UInt64>)->ClosedRange<UInt64>?{
        let size = self.storage.size
        if range.lowerBound >= size{
            return nil
        }
        
        if range.upperBound >= size - 1{
            return range.lowerBound ... size - 1
        }
        return range
    }
    public func download(indx:UInt64) throws {
        guard let range = self.range(indx: indx) else { throw NSError(domain: "out of range", code: 0, userInfo: nil) }
        try self.download(range: range)
    }
    public func download(range:ClosedRange<UInt64>) throws {
        guard let ran = self.checkRange(range: range) else {
            throw NSError(domain: "out of range", code: 0, userInfo: nil)
        }
        let rs = self.cutRange(range: ran)
        for i in rs {
            
            if !self.storage.complete(range: i){
//                print(i)
                
                let id = CokeSession.shared.data(url: self.url, range: i) { (resp) -> URLSession.ResponseDisposition in
                    guard let res = resp else { return .cancel }
                    if res.statusCode >= 200 && res.statusCode < 300{
                        self.setMetaData(rep: res)
                        return .allow
                    }else{
                        return .cancel
                    }
                    
                } handleData: { (data, resp, range) in
                    try? self.storage.saveData(data: data, index: range.lowerBound)
                } complete: { (resp, e) in
                    if e == nil{
                        guard let res = resp else { return }
                        self.setMetaData(rep: res)
                        try? self.storage.close()
                    }
                }
                self.downId[i] = id
            }
        }
        
    }
    public func cutRange(range:ClosedRange<UInt64>)->[ClosedRange<UInt64>]{
        var ranges = [range]
        while ranges.first!.upperBound + 1 - ranges.first!.lowerBound > self.page {
            let l = ranges.first!.lowerBound ... ranges.first!.lowerBound + self.page - 1
            let r = ranges.first!.lowerBound + self.page ... ranges.first!.upperBound
            ranges = [r,l]
        }
        return ranges
    }
    public func download( callback:@escaping()->Void){
        if self.storage.isComplete{
            callback()
            return
        }
        if self.storage.dataHeader.size > 0{
            CokeSession.shared.beginGroup {
                for i in self.storage.dataHeader.noDataRanges {
                    try? self.download(range: i)
                }
            } notify: {
                if !self.storage.isComplete{
                    self.download(callback: callback)
                }else{
                    callback()
                }
            }
        }else{
            CokeSession.shared.beginGroup {
                self.prepare()
            } notify: {
                CokeSession.shared.beginGroup {
                    for i in 0 ..< self.count {
                        try? self.download(indx: i)
                    }
                } notify: {
                    if !self.storage.isComplete{
                        self.download(callback: callback)
                    }else{
                        callback()
                    }
                }
            }
        }
        
    }
    public subscript(offset:UInt64)->Data?{
        guard let range = self.storage.dataRanges.filter({$0.contains(offset)}).first else { return nil}
        let useRange = offset ... range.upperBound
        return self.storage[useRange]
    }

    public func cancel(range:ClosedRange<UInt64>){
        if let i = self.downId[range]{
            CokeSession.shared.cancel(identify: i)
        }
    }
    public func cancel(index:UInt64){
        for i in self.downId {
            if i.key.lowerBound == index{
                self.cancel(range: i.key)
            }
        }
    }
    public func prepare(){
        if self.storage.size == 0{
            _ = CokeSession.shared.head(url: self.url) { r, _, _, e in
                guard let rep = r else { return }
                self.setMetaData(rep: rep)
            }
        }
        
    }
    private func setMetaData(rep:HTTPURLResponse){
        self.storage.dataHeader.etag = rep.header(key: "Etag")
        self.storage.dataHeader.lastRequestDate = rep.header(key: "Last-Modified")
        self.storage.dataHeader.status = rep.statusCode
        self.storage.dataHeader.expiresDate = rep.header(key: "Expires")
        self.storage.dataHeader.url = rep.url
        if let ra = self.getRange(rep: rep){
            self.storage.size = ra.1
        }else{
            self.storage.size = 0
        }
        self.storage.resourceType = rep.header(key: "Content-Type") ?? "Data"
        try? self.storage.close()
    }
    private func getRange(rep:HTTPURLResponse)->(ClosedRange<UInt64>,UInt64)?{
        if let info = rep.header(key: "Content-Range"){
            let rangeInfo = info.components(separatedBy: "/")
            guard let size = rangeInfo.last,let sizen = UInt64(size) else { return nil }
            guard let rage =  rangeInfo.first?.components(separatedBy: .whitespaces).last else { return nil }
            guard let s = rage.components(separatedBy: "-").first ,let start = UInt64(s) else { return nil}
            guard let e = rage.components(separatedBy: "-").last ,let end = UInt64(e) else { return nil }
            return (start...end,sizen)
        }else if let info = rep.header(key: "Content-Length"){
            let len = (UInt64(info) ?? 1)
            if len >= 1 {
                return (0...len - 1,len)
            }
            return (0...0,0)
            
        }
        return nil
    }
    private var downId:[ClosedRange<UInt64>:Int] = [:]
}
