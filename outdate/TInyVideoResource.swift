//
//  CokeVideoResource.swift
//  PEVideo
//
//  Created by hao yin on 2020/12/14.
//

import Foundation
import AVFoundation

public struct VideoCacheInfo:Codable{
    var type:String
    var contentSize:Int
    var map:[ClosedRange<Int>]
}

public protocol FileCache{
    var cacheInfo:VideoCacheInfo { get }
    func hasData(index:Int)->ClosedRange<Int>?
    
    subscript(current:Int)->Data? { get  set }
    init(identify:String)
    var identify:String { get }
    var isFull:Bool { get }
    mutating func  config(size:Int,type:String)
}
public let pageSize:Int = 512 * 1024

public struct VideoDiskCache:FileCache{
    public init(identify: String) {
        self.cacheInfo = VideoCacheInfo(type: "", contentSize: 0, map: [])
        if let ida  = identify.data(using: .utf8){
            self.identify = CokeHash.md5(data: ida).hexString
        }else{
            self.identify = UUID().uuidString
        }
        if let l = self.localUrl{
            self.loadLocal(url: l)
        }
    }
    
    public var identify: String
    public static var sem:DispatchSemaphore = DispatchSemaphore(value: 1)

    public var cacheInfo: VideoCacheInfo{
        didSet{
            if let bU = self.localUrl{
                do{
                    try JSONEncoder().encode(self.cacheInfo).write(to: bU.appendingPathExtension("map"))
                }catch{
                    
                }
            }
            
        }
    }
    
    public mutating func loadLocal(url:URL){
        let u = url.appendingPathExtension("map")
        do {
            var dic:ObjCBool = false
            let flag = FileManager.default.fileExists(atPath: url.path, isDirectory: &dic)
            if(flag && !dic.boolValue){
                let data = try Data(contentsOf: u)
                self.cacheInfo = try JSONDecoder().decode(VideoCacheInfo.self, from: data)
            }
        } catch  {
            
        }
    }

    public func hasData(index: Int) -> ClosedRange<Int>? {
        if let fi = self.cacheInfo.map.filter({$0.contains(index)}).first{
            return index ... fi.upperBound
        }
        return nil
    }

    public subscript(current: Int) -> Data? {
        get {
            if let rage = self.hasData(index: current){
                var data = self.readData(range: rage)
                if let next = self.hasData(index: rage.upperBound + 1){
                    let d = self[next.lowerBound]
                    data?.append(d!)
                }
                return data
            }else{
                return nil
            }
        }
        set {
            if let data = newValue{
                let closeRage = current ... (current + data.count - 1)
                self.writeData(index: current, data: data)
                var match = self.cacheInfo.map.filter { (cu) -> Bool in cu.overlaps(closeRage) || cu.contains(closeRage.lowerBound - 1) || cu.contains(closeRage.upperBound + 1)}
                
                if match.count > 0{
                    match.append(closeRage)
                    let hmax = match.max { $0.upperBound < $1.upperBound }
                    let hmin = match.min { $0.lowerBound < $1.lowerBound }
                    let inrage = hmin!.lowerBound ... hmax!.upperBound
                    var offmatch = self.cacheInfo.map.filter { (cu) -> Bool in !cu.overlaps(closeRage) && !cu.contains(closeRage.lowerBound - 1) && !cu.contains(closeRage.upperBound + 1)}
                    offmatch.append(inrage)
                    self.cacheInfo.map = offmatch
                }else{
                    self.cacheInfo.map.append(closeRage)
                }
                
            }
        }
    }
    public  mutating func config(size: Int, type: String) {
        self.cacheInfo.contentSize = size
        self.cacheInfo.type = type
        self.writeData(index: 0, data: Data(count: size))
    }
    func readData(range:ClosedRange<Int>)->Data?{
        do {
            if let url = self.localUrl{
                let handle = try FileHandle(forReadingFrom: url)
                if #available(iOS 13.4, *) {
                    try handle.seek(toOffset: UInt64(range.lowerBound))
                    let data = try handle.read(upToCount: range.upperBound - range.lowerBound + 1)
                    try handle.close()
                    return data
                } else {
                    handle.seek(toFileOffset: UInt64(range.lowerBound))
                    let data = handle.readData(ofLength: range.upperBound - range.lowerBound + 1)
                    handle.closeFile()
                    return data
                }
                
            }else{
                return nil
            }
        } catch {
            return nil
        }
    }
    
    func writeData(index:Int,data:Data){
        do {
            VideoDiskCache.sem.wait()
            if let url = self.localUrl{
                let handle = try FileHandle(forWritingTo: url)
                if #available(iOS 13.4, *) {
                    try handle.seek(toOffset: UInt64(index))
                    try handle.write(contentsOf: data)
                    try handle.close()
                } else {
                    handle.seek(toFileOffset: UInt64(index))
                    handle.write(data)
                    handle.closeFile()
                }
            }
            VideoDiskCache.sem.signal()
        } catch {
            
        }
    }
    public var localUrl:URL?{
        if let url = VideoDiskCache.cacheDic?.appendingPathComponent(self.identify).appendingPathExtension("mp4"){
            if !FileManager.default.fileExists(atPath: url.path){
                FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil)
                let u = url.appendingPathExtension("map")
                try? FileManager.default.removeItem(at: u)
            }
            return url
        }
        return nil
    }
    public static var cacheDic:URL?{
        if let u = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("PEVideo"){
            var a:ObjCBool = false
            let b = FileManager.default.fileExists(atPath: u.path, isDirectory: &a)
            if a.boolValue && b{
                return u
            }else{
                do {
                    try FileManager.default.createDirectory(at: u, withIntermediateDirectories: true, attributes: nil)
                    return u;
                } catch  {
                    return nil
                }
            }
        }
        return nil
    }
    public var isFull:Bool{
        self.cacheInfo.map.count == 1 && self.cacheInfo.map.first!.upperBound - self.cacheInfo.map.first!.lowerBound == self.cacheInfo.contentSize - 1
    }
}
public class CokeVideoResource<T:FileCache>:NSObject,AVAssetResourceLoaderDelegate{
    
    public typealias CallBack = (Data?,Error?)->Void
    public typealias DownloadSuccessCallback = (URL?)->Void
    let url:URL
    var sem:DispatchSemaphore = DispatchSemaphore(value: 1)
    var cache:T
    var queue:DispatchQueue
    var identify:String
    var tasks:[Int:URLSessionTask] = [:]
    public var downloadSuccess:DownloadSuccessCallback?
    public init?(url:URL,identify:String,queue:DispatchQueue) {
        self.queue = queue
        self.url = url;
        self.cache = T(identify: url.absoluteString)
        self.identify = identify
        super.init()
        guard self.videoUrl != nil else { return nil }
    }
    public var asset:AVAsset{
        let u = AVURLAsset(url: self.videoUrl!)
        u.resourceLoader.setDelegate(self, queue: self.queue)
        return u
    }
    public var videoUrl:URL?{
        var c = URLComponents(url: self.url, resolvingAgainstBaseURL: true)
        c?.scheme = "id" + self.identify
        if let v = c?.url{
            return v
        }
        return nil
    }
    public func preload(req:AVAssetResourceLoadingRequest){
        self.queue.async {
            self.sem.wait()
            self.prepare {(_, e) in
                if((e) != nil){
                    req.finishLoading(with: e)
                }else{
                    req.contentInformationRequest?.contentLength = Int64(self.cache.cacheInfo.contentSize)
                    req.contentInformationRequest?.contentType = self.cache.cacheInfo.type
                    req.contentInformationRequest?.isByteRangeAccessSupported = true
                    req.finishLoading()
                }
                self.sem.signal()
            }
        }
    }
    public func requestData(req:AVAssetResourceLoadingRequest){
        self.queue.async {
            self.sem.wait()
            if let dataRe = req.dataRequest{
                self.requestIndex(index: Int(dataRe.currentOffset)) {(d, e) in
                    if((e) != nil){
                        req.finishLoading(with: e)
                    }else{
                        if let data = d{
                            req.dataRequest?.respond(with:data)
                        }
                        req.finishLoading()
                    }
                    self.sem.signal()
                }
            }else{
                self.sem.signal()
            }
        }
        
    }
    func prepare(callback:CallBack? = nil){
        if self.cache.cacheInfo.contentSize <= 0{
            var req = URLRequest(url: self.url)
            req.httpMethod = "head"
            let task = CokeVideoResourceManager.shared.dataTask(with: req) {[weak self](d, re, e) in
                if let httprep = re as? HTTPURLResponse{
                    if let u = (httprep.allHeaderFields["Content-Length"] as? String){
                        let size = Int(u) ?? 0
                        if (size > 0){
                            self?.cache.config(size: size, type: AVFileType.mp4.rawValue)
                            callback?(d,e)
                            return
                        }
                    }
                }
                callback?(d,NSError(domain: "no contentSize", code: 0, userInfo: nil))
            }
            task.resume()
            self.tasks[0] = task
        }else{
            self.queue.async {
                callback?(nil,nil)
            }
            
        }
    }
    func requestIndex(index:Int,callback:CallBack? = nil){
        if let data = self.cache[index]{
            self.queue.async {
                callback?(data,nil)
            }
        }else{
            var req = URLRequest(url: self.url)
            let last = (index + pageSize - 1) > self.cache.cacheInfo.contentSize ?  self.cache.cacheInfo.contentSize - 1 : index + pageSize - 1
            req.addValue("bytes=\(index)-\(last)", forHTTPHeaderField: "Range")
            let task = CokeVideoResourceManager.shared.dataTask(with: req) { [weak self](d, re, e) in
                if let httprep = re as? HTTPURLResponse{
                    if httprep.statusCode == 206 && e == nil && (d?.count ?? 0) > 0 {
                        var nd = Data()
                        nd.append(d!)
                        self?.cache[index] = nd
                        callback?(nd,nil)
                    }else{
                        if httprep.statusCode == 416 {
                            let err = NSError(domain: "download error", code: 0, userInfo: nil)
                            callback?(d,err)
                        }else{
                            let err = NSError(domain: "download error", code: 1, userInfo: nil)
                            callback?(d,err)
                        }
                    }
                }else{
                    let err = NSError(domain: "download error", code: 1, userInfo: nil)
                    callback?(d,err)
                }
                
            }
            task.resume()
            self.tasks[index] = task
        }
    }

    public func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        if((loadingRequest.contentInformationRequest) != nil){
            self.tasks[0]?.cancel()
        }else{
            if let datarq = loadingRequest.dataRequest{
                self.tasks[Int(datarq.currentOffset)]?.cancel()
            }
        }
    }
    public func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        if((loadingRequest.contentInformationRequest) != nil){
            self.preload(req: loadingRequest)
        }else{
            self.requestData(req: loadingRequest)
        }
        return true
    }
    
}


public let backgroundId = "CokeVideoResource.session"

public class CokeVideoResourceManager:NSObject,URLSessionDataDelegate{
    
    var queue:DispatchQueue
    
    public typealias SessionCallback = (Data?,URLResponse?,Error?)->Void
    
    public class SessionData{
        var callback:SessionCallback?
        var data:Data?
    }
    
    var session:URLSession!
    
    var loader: [URL:CokeVideoResource<VideoDiskCache>] = [:]
    
    var tasks:[URLSessionTask:SessionData] = [:]
    
    @objc public static var shared:CokeVideoResourceManager = {
        CokeVideoResourceManager()
    }()
    
    @objc public func load(url:URL,identify:String,preload:Bool = false)->AVAsset?{
        self.loadResource(url: url, identify: identify, preload: preload)?.asset
    }
    public func loadResource(url:URL,identify:String,preload:Bool = false)->CokeVideoResource<VideoDiskCache>?{
        let a = CokeVideoResource<VideoDiskCache>(url: url,identify: identify,queue: self.queue)
        self.loader[url] = a;
        return a
    }
    public func dataTask(with:URLRequest,callback:SessionCallback?)->URLSessionDataTask{
        let task = self.session.dataTask(with: with)
        let sd = SessionData()
        sd.data = Data()
        sd.callback = callback
        self.tasks[task] = sd;
        return task
    }
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if self.tasks[dataTask]?.data == nil{
            self.tasks[dataTask]?.data = data
        }else{
            self.tasks[dataTask]?.data?.append(data)
        }
    }
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let data =  self.tasks[task]?.data
        self.tasks[task]?.callback?(data,task.response,error)
        self.tasks[task] = nil;
    }

    
    
    public override init() {
        self.queue = DispatchQueue(label: "PEVideoResourceManager", qos: .background, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)
        super.init()
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
    }
    public func download(url:URL,indx:Int,identify:String,callback: @escaping (URL?)->Void){
        var old = self.loader[url]
        if old == nil{
            old = CokeVideoResource<VideoDiskCache>(url: url,identify: identify,queue: self.queue)
        }
        guard let a = old else {
            callback(nil)
            return
        }
        if(a.cache.isFull){
            callback(a.cache.localUrl)
            return
        }
        a.prepare(callback: {(d, e) in
            if(e == nil){
                a.requestIndex(index: indx) { (d, e) in
                    if(e == nil){
                        self.download(url: url, indx: indx + pageSize,identify: identify, callback: callback)
                    }else{
                        if(a.cache.isFull){
                            callback(a.cache.localUrl)
                            return
                        }else{
                            callback(nil)
                            return
                        }
                    }
                }
            }else{
                if(a.cache.isFull){
                    callback(a.cache.localUrl)
                    return
                }else{
                    callback(nil)
                    return
                }
            }
        })
    }
    
    @objc public func download(url:URL,identidy:String,callback: @escaping (URL?)->Void){
        
        
        var old = self.loader[url]
        if old == nil{
            old = CokeVideoResource<VideoDiskCache>(url: url,identify: identidy,queue: self.queue)
        }
        guard let a = old else {
            callback(nil)
            return
        }
        if(a.cache.isFull){
            callback(a.cache.localUrl)
            a.downloadSuccess?(a.cache.localUrl)
        }else{
            a.queue.async {
                a.sem.wait()
                self.download(url: url, indx: 0,identify: identidy) { (u) in
                    a.sem.signal()
                    callback(u)
                    
                }
            }
        }
    }
}
