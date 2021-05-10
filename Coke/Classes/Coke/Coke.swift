//
//  WebSource.swift
//  test
//
//  Created by hao yin on 2021/4/13.
//

import Foundation
import CommonCrypto
import AVFoundation

public protocol CokeStorage{
    func saveData(data:Data,index:UInt64) throws
    func saveData(url:URL,index:UInt64) throws
    func loadData()->Data?
    var identify:String { get }
    init(dir:URL,identify:String) throws
    var size:UInt64 { get set }
    var resourceType:String { get set }
    var isComplete:Bool { get }
    func complete(range:ClosedRange<UInt64>)->Bool
    var percent:Float { get }
    var dataRanges:[ClosedRange<UInt64>] {get}
    func delete() throws
    func close() throws
    var dataHeader:CokeHeaderData { get set }
    subscript(range:ClosedRange<UInt64>)->Data? { get }
    subscript(index:UInt64)->Data? { get }
}

extension CokeStorage{
    public static func digest(name:String)->String?{
        guard let data = name.data(using: .utf8) else { return nil }
        let p = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
        data.copyBytes(to: p, count: data.count)
        let r = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256(p, CC_LONG(data.count), r)
        let d = Data(bytes: r, count: Int(CC_SHA256_DIGEST_LENGTH)).reduce("") { (a, b) -> String in
            a + String(format: "%x", b)
        }
        p.deallocate()
        r.deallocate()
        return d
    }
    public static var documentDir:URL?{
        guard let u = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("WebSourceDownloader") else { return nil }
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true, attributes: nil)
        return u
    }
    public static var cacheDictionary:URL?{
        guard let u = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("WebSourceDownloader") else { return nil }
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true, attributes: nil)
        return u
    }
}

public class CokeSession:NSObject,URLSessionDataDelegate,URLSessionDownloadDelegate{
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let task = downloadTask as URLSessionTask
        self.dataMap[task.taskIdentifier]?.url = location
        let call = self.dataMap[task.taskIdentifier]?.handleDataComplete
        call?(task.response as? HTTPURLResponse,location,nil, nil)
        self.dataMap[task.taskIdentifier]?.handleFile?(location,downloadTask.response as? HTTPURLResponse,nil)
    }
    public typealias HandleData = (Data,HTTPURLResponse?,ClosedRange<UInt64>)->Void
    public typealias HandleFile = (URL?,HTTPURLResponse?,Error?)->Void
    public typealias HandleResponse = (HTTPURLResponse?)->URLSession.ResponseDisposition
    public typealias HandleComplete = (HTTPURLResponse?,Error?)->Void
    public typealias HandleDataComplete = (HTTPURLResponse?,URL?,Data?,Error?)->Void
    

    public static var shared:CokeSession = {
        CokeSession()
    }()
    public var queue = DispatchQueue(label: "WebSourceSession", qos: .background, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)
    public lazy var urlSession:URLSession = {
        let q = OperationQueue()
        q.name  = "WebSourceSession"
        q.maxConcurrentOperationCount = 999
        q.underlyingQueue = self.queue
        return URLSession(configuration: .ephemeral, delegate: self, delegateQueue: q)
    }()
   
    public func data(url:URL,range:ClosedRange<UInt64>? = nil,handleResponse: HandleResponse? = nil ,handleData: @escaping HandleData,complete:@escaping HandleComplete)->Int{
        return self.data(request: URLRequest(url: url), range: range ,handleResponse: handleResponse, handleData: handleData, complete: complete)
    }
    public func head(url:URL,call:@escaping HandleDataComplete)->Int{
        var r = URLRequest(url: url)
        r.httpMethod = "get"
        r.setValue("bytes=\(0)-\(1)", forHTTPHeaderField: "Range")
        return self.data(request: r, dataComplete: call)
    }
    public func data(url:URL,range:ClosedRange<UInt64>? = nil,handleResponse: HandleResponse? = nil,dataComplete:@escaping HandleDataComplete)->Int{
        let urlr = URLRequest(url: url)
        return self.data(request: urlr, range: range, handleResponse: handleResponse, dataComplete: dataComplete)
        
    }
    public func data(request:URLRequest,range:ClosedRange<UInt64>? = nil,handleResponse: HandleResponse? = nil,handleData: @escaping HandleData,complete:@escaping HandleComplete)->Int{
        group?.enter()
        var req = request
        if let r = range{
            req.setValue("bytes=\(r.lowerBound)-\(r.upperBound)", forHTTPHeaderField: "Range")
        }
        let task = self.urlSession.dataTask(with:req)
        let model = WebSourceDownloadModel(handleResponse: handleResponse, handleData: handleData, handleComplete: complete, handleDataComplete: nil, handleFile: nil, index: range?.lowerBound ?? 0, task: task, data: Data(),group:group)
        self.queue.async(execute: DispatchWorkItem.init(qos: .userInteractive, flags: .barrier, block: {
            self.dataMap[task.taskIdentifier] = model
            DispatchQueue.global().async {
                model.semaphore?.wait()
                task.resume()
            }
        }))
        return task.taskIdentifier
    }
    public func data(request:URLRequest,range:ClosedRange<UInt64>? = nil,handleResponse:HandleResponse? = nil,dataComplete:@escaping HandleDataComplete)->Int{
        group?.enter()
        
        var req = request
        if let r = range{
            req.setValue("bytes=\(r.lowerBound)-\(r.upperBound)", forHTTPHeaderField: "Range")
        }
        let task = self.urlSession.dataTask(with:req)
        let model = WebSourceDownloadModel(handleResponse: handleResponse, handleData: nil, handleComplete: nil, handleDataComplete: dataComplete, handleFile: nil, index: range?.lowerBound ?? 0, task: task, data: Data(),group:group)
        
        
        self.queue.async(execute: DispatchWorkItem.init(qos: .userInteractive, flags: .barrier, block: {
            self.dataMap[task.taskIdentifier] = model
            DispatchQueue.global().async {
                model.semaphore?.wait()
                task.resume()
            }
        }))
        return task.taskIdentifier
    }
    public func file(request:URLRequest,range:ClosedRange<UInt64>? = nil,handle:@escaping HandleFile)->Int{
        group?.enter()
        
        var req = request
        if let r = range{
            req.setValue("bytes=\(r.lowerBound)-\(r.upperBound)", forHTTPHeaderField: "Range")
        }
        let task = self.urlSession.downloadTask(with: req)
        let model = WebSourceDownloadModel(handleResponse: nil, handleData: nil, handleComplete: nil, handleDataComplete: nil, handleFile: handle, index: range?.lowerBound ?? 0, task: task, data: Data(),group:group)
        self.queue.async(execute: DispatchWorkItem.init(qos: .userInteractive, flags: .barrier, block: {
            self.dataMap[task.taskIdentifier] = model
            DispatchQueue.global().async {
                model.semaphore?.wait()
                task.resume()
            }
        }))
        return task.taskIdentifier
    }
    public func file(url:URL,range:ClosedRange<UInt64>? = nil,handle:@escaping HandleFile)->Int{
        let req = URLRequest(url: url)
        return self.file(request: req, range: range ,handle: handle)
    }
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        
        let task = dataTask as URLSessionTask
        if self.dataMap[task.taskIdentifier] != nil {
            if let callback = self.dataMap[task.taskIdentifier]?.handleData{
                let range = self.dataMap[task.taskIdentifier]!.index ... UInt64(data.count) + self.dataMap[task.taskIdentifier]!.index - 1
                self.dataMap[task.taskIdentifier]?.index += UInt64(data.count)
                callback(data,task.response as? HTTPURLResponse, range)
            }
            self.dataMap[task.taskIdentifier]?.data.append(data)
        }
    }
    public func cancel(identify:Int){
        self.dataMap[identify]?.task.cancel()
    }
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        self.dataMap[task.taskIdentifier]?.handleComplete?(task.response as? HTTPURLResponse,error)
        self.dataMap[task.taskIdentifier]?.handleDataComplete?(task.response as? HTTPURLResponse,nil,self.dataMap[task.taskIdentifier]?.data,error)
        if (error != nil){
            self.dataMap[task.taskIdentifier]?.handleFile?(nil,task.response as? HTTPURLResponse,error)
        }
        self.dataMap[task.taskIdentifier]?.group?.leave()
        self.dataMap[task.taskIdentifier]?.semaphore?.signal()
        self.queue.async(execute: DispatchWorkItem(qos: .userInteractive, flags: .barrier, block: {
            self.dataMap.removeValue(forKey: task.taskIdentifier)
        }))
        
    }
    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        self.queue.async(execute: DispatchWorkItem(qos: .userInteractive, flags: .barrier, block: {
            for i in self.dataMap.values{
                i.handleComplete?(nil,error)
                i.handleFile?(nil,nil,error)
                i.group?.leave()
                i.semaphore?.signal()
            }
            self.dataMap.removeAll()
        }))
    }
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
        let task = dataTask as URLSessionTask
        let dtask = downloadTask as URLSessionTask
        self.queue.async(execute: DispatchWorkItem(qos: .userInteractive, flags: .barrier, block: {
            if(task.taskIdentifier != dtask.taskIdentifier){
                self.dataMap[dtask.taskIdentifier] = self.dataMap[task.taskIdentifier]
            }
        }))
        
    }
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        let task = dataTask as URLSessionTask
        if self.dataMap[task.taskIdentifier] != nil {
            if let resp = response as? HTTPURLResponse{
                let state = self.dataMap[task.taskIdentifier]?.handleResponse?(resp)
                completionHandler(state ?? .allow)
            }else{
                completionHandler(.cancel)
            }
        }else{
            completionHandler(.cancel)
        }
        
    }
    private var group:DispatchGroup?{
        self.groups.last
    }
    
    private var groups:[DispatchGroup] = []
    
    public func beginGroup(build:@escaping ()->Void,notify:@escaping ()->Void){
        self.queue.async(execute: DispatchWorkItem(qos: .userInteractive, flags: .barrier, block: {
            let g = DispatchGroup()
            self.groups.append(g)
            build()
            self.groups.removeLast().notify(qos: .userInteractive, flags: .barrier, queue: self.queue, execute: notify)
        }))
    }
    
    private class WebSourceDownloadModel{
        var handleResponse:HandleResponse?
        var handleData:HandleData?
        var handleComplete:HandleComplete?
        var handleDataComplete:HandleDataComplete?
        var handleFile:HandleFile?
        var index:UInt64 = 0
        var task:URLSessionTask
        var url:URL?
        var data:Data
        var group:DispatchGroup?
        var semaphore:DispatchSemaphore?
        init(handleResponse:HandleResponse?,
             handleData: HandleData?,
             handleComplete: HandleComplete?,
             handleDataComplete: HandleDataComplete?,
             handleFile:HandleFile?,
             index:UInt64,task:URLSessionTask,
             data:Data,group:DispatchGroup?) {
            self.handleData = handleData
            self.handleResponse  = handleResponse
            self.handleComplete = handleComplete
            self.handleDataComplete = handleDataComplete
            self.handleFile = handleFile
            self.index = index
            self.task = task
            self.data = data
            self.group = group
        }
    }
    private var dataMap:[Int:WebSourceDownloadModel] = [:]
    
    private var timer:DispatchSourceTimer = DispatchSource.makeTimerSource()
    deinit {
        self.urlSession.finishTasksAndInvalidate()
        self.timer.cancel()
    }
    
}
extension URL:ExpressibleByStringLiteral{
    public typealias StringLiteralType = String
    
    public init(stringLiteral value: String) {
        self.init(string: value)!
    }
}
extension HTTPURLResponse{
    public func header(key:String)->String?{
        return self.allHeader[key.lowercased()]
    }
    public var allHeader:[String:String]{
        (self.allHeaderFields as! [String:String]).reduce([:]) { (last, current) -> [String:String] in
            var l = last
            l[current.key.lowercased()] = current.value
            return l
        }
    }
}


public class CokeCModel<T:AnyObject>{
    public var content:T?
    public init(content:T? = nil){
        self.content = content
    }
}


open class CokeRunloopSource<T:Any>{
    private var context: CFRunLoopSourceContext?
    
    public var mode: CFRunLoopMode = .defaultMode
    
    public var runloop: CFRunLoop?
    
    open func start() {
        print("start")
    }
    
    open func end() {
        print("end")
    }
    
    open func perform() {
        print("perform")
    }
    
    public init(order:Int) throws {
        self.model.content = self
        pthread_mutex_init(self.mutex, nil)
        pthread_cond_init(self.con, nil)
        createRunloopSourceContext(info: &self.model)
        try createRunloopSource(info: &self.model, order: order)
    }
    
    private var model:CokeCModel<CokeRunloopSource> = CokeCModel()
    
    private var source: CFRunLoopSource!
    
    private var mutex:UnsafeMutablePointer<pthread_mutex_t> = .allocate(capacity: 1)
    private var con:UnsafeMutablePointer<pthread_cond_t> = .allocate(capacity: 1)
    
}

extension CokeRunloopSource {
    public func createRunloopSourceContext(info:UnsafeMutableRawPointer){
        var ctx = CFRunLoopSourceContext()
        ctx.info = info
        ctx.version = 0
        ctx.perform = { i in
            i?.assumingMemoryBound(to: CokeCModel<CokeRunloopSource<Any>>.self).pointee.content?.perform()
        }
        ctx.schedule = { i,r,m in
            let p = i?.assumingMemoryBound(to: CokeCModel<CokeRunloopSource<Any>>.self).pointee.content
            p?.runloop = r
            p?.mode = m ?? .defaultMode
            p?.start()
        }
        ctx.cancel = { i, r, m in
            let p = i?.assumingMemoryBound(to: CokeCModel<CokeRunloopSource<Any>>.self).pointee
            p?.content?.runloop = nil
            p?.content?.end()
            p?.content = nil
        }
        self.context = ctx
    }
    
    public func createRunloopSource(info:UnsafeMutableRawPointer,order:Int) throws {
        guard let source = CFRunLoopSourceCreate(kCFAllocatorDefault, order, &(self.context!)) else {
            throw NSError(domain:" create runloop source fail", code: 0, userInfo: nil)
        }
        self.source = source
    }
    public func addRunloop(runloop:CFRunLoop,mode:RunLoop.Mode){
        CFRunLoopAddSource(runloop, self.source, CFRunLoopMode(rawValue: mode.rawValue as CFString))
    }
    public func cancel(){
        guard let rl = self.runloop else { return }
        CFRunLoopRemoveSource(rl, self.source, mode)
    }
    public func signal(model:T){
        guard let rl = self.runloop else { return }
        if !CFRunLoopIsWaiting(rl){
            pthread_cond_wait(self.con, self.mutex)
        }
        CFRunLoopSourceSignal(self.source)
        CFRunLoopWakeUp(rl)
    }
    
    
}

public class CokeRunloopObserver{
    private var observerCtx:CFRunLoopObserverContext?
    private var observer:CFRunLoopObserver!
    private var model:CokeCModel<CokeRunloopObserver> = CokeCModel()
    private var mode:CFRunLoopMode = .defaultMode
    private var runloop:CFRunLoop?
    func createRunloopObseverContext(info:UnsafeMutableRawPointer){
        var ctx = CFRunLoopObserverContext()
        ctx.info = info
        ctx.version = 0
        self.observerCtx = ctx
    }
    func createRunloopObsever(info:UnsafeMutableRawPointer,activity:CFRunLoopActivity,order:Int,call:@escaping ()->Void) throws {
        self.observer = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, activity.rawValue, true, order) { o, a in
            call()
        }
        if self.observer == nil{
            throw NSError(domain:" create runloop observer fail", code: 0, userInfo: nil)
        }
    }
    
    public func addRunloop(runloop:CFRunLoop,mode:RunLoop.Mode){
        self.runloop = runloop
        self.mode = CFRunLoopMode(rawValue: mode.rawValue as CFString)
        CFRunLoopAddObserver(runloop, self.observer,self.mode)
    }
    public func cancel(){
        guard let rl = self.runloop else { return }
        CFRunLoopRemoveObserver(rl, self.observer, self.mode)
        self.runloop = nil
    }
    public init(order:Int,activity:CFRunLoopActivity,call:@escaping ()->Void) throws{
        self.model.content = self
        self.createRunloopObseverContext(info: &self.model)
        try self.createRunloopObsever(info: &self.model, activity: activity, order: order, call: call)
    }
    
}
