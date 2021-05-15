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
   
    public func data(url:URL,range:ClosedRange<UInt64>? = nil,handleResponse: HandleResponse? = nil ,handleData: @escaping HandleData,complete:@escaping HandleComplete)->URLSessionTask{
        return self.data(request: URLRequest(url: url), range: range ,handleResponse: handleResponse, handleData: handleData, complete: complete)
    }
    public func head(url:URL,call:@escaping HandleDataComplete)->URLSessionTask{
        var r = URLRequest(url: url)
        r.httpMethod = "get"
        r.setValue("bytes=\(0)-\(1)", forHTTPHeaderField: "Range")
        return self.data(request: r, dataComplete: call)
    }
    public func data(url:URL,range:ClosedRange<UInt64>? = nil,handleResponse: HandleResponse? = nil,dataComplete:@escaping HandleDataComplete)->URLSessionTask{
        let urlr = URLRequest(url: url)
        return self.data(request: urlr, range: range, handleResponse: handleResponse, dataComplete: dataComplete)
        
    }
    public func data(request:URLRequest,range:ClosedRange<UInt64>? = nil,handleResponse: HandleResponse? = nil,handleData: @escaping HandleData,complete:@escaping HandleComplete)->URLSessionTask{
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
        return task
    }
    public func data(request:URLRequest,range:ClosedRange<UInt64>? = nil,handleResponse:HandleResponse? = nil,dataComplete:@escaping HandleDataComplete)->URLSessionTask{
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
        return task
    }
    public func file(request:URLRequest,range:ClosedRange<UInt64>? = nil,handle:@escaping HandleFile)->URLSessionTask{
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
        return task
    }
    public func file(url:URL,range:ClosedRange<UInt64>? = nil,handle:@escaping HandleFile)->URLSessionTask{
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
        self.queue.async(execute: DispatchWorkItem(qos: .userInteractive, flags: .barrier, block: {
            self.dataMap[identify]?.task.cancel()
        }))

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
            self.groups.removeLast().notify(qos: .userInteractive, flags: .barrier, queue: self.queue,execute: notify)
        }))
    }
    public func beginGroup(@TaskBuild builder:@escaping ()->[URLSessionTask],notifier:@escaping ([URLSessionTask])->Void){
        self.queue.async(execute: DispatchWorkItem(qos: .userInteractive, flags: .barrier, block: {
            let g = DispatchGroup()
            self.groups.append(g)
            let tasks = builder()
            self.groups.removeLast().notify(qos: .userInteractive, flags: .barrier, queue: self.queue) {
                notifier(tasks)
            }
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

public class CokeRunloop{
    public private(set) var runloop:RunLoop!
    public func close(){
        CFRunLoopRemoveSource(self.runloop.getCFRunLoop(), self.source.cfsource, .commonModes)
        CFRunLoopStop(self.runloop.getCFRunLoop())
        pthread_mutex_destroy(self.lock)
        self.lock.deallocate()
    }
    public init(){
        var thread:pthread_t?
        pthread_mutex_init(self.lock, nil)
        pthread_mutex_lock(self.lock)
        pthread_create(&thread, nil, { i in
            let l = Unmanaged<CokeRunloop>.fromOpaque(i).takeUnretainedValue()
            l.runloop = RunLoop.current
            pthread_setname_np("CokeRunloop")
            
            pthread_mutex_unlock(l.lock)
            l.addSource()
            RunLoop.current.run()
            return i
        }, Unmanaged.passUnretained(self).toOpaque())
        pthread_mutex_lock(self.lock)
    }
    
    private var lock = UnsafeMutablePointer<pthread_mutex_t>.allocate(capacity: 1)
    
    private lazy var source:CokeRunloopSource = {
        return CokeRunloopSource { [weak self] in
        
        }
    }()
    private func addSource(){
        CFRunLoopAddSource(self.runloop.getCFRunLoop(), self.source.cfsource, .commonModes)
    }
    deinit {
        self.close()
    }
}
public class CokeRunloopSource{
    
    lazy var sourceContext:CFRunLoopSourceContext = {
        var context = CFRunLoopSourceContext()
        context.version = 0
        context.info = Unmanaged.passUnretained(self).toOpaque()
        context.perform = { i in
            i?.assumingMemoryBound(to: CokeRunloopSource.self).pointee.perform()
        }
        return context
    }()
    public lazy var cfsource:CFRunLoopSource = {
        CFRunLoopSourceCreate(kCFAllocatorSystemDefault, 0, &self.sourceContext)
    }()
    private var call:(()->Void)?
    init(call:@escaping ()->Void) {
        self.call = call
    }
    func perform(){
        self.call?()
    }
}
public class CokeRunloopObserver{
    public private(set) var observer:CFRunLoopObserver!
    public init(activitys:CFRunLoopActivity,order:Int,repeatObserver:Bool,callback:@escaping (CFRunLoopActivity)->Void){
        
        let ob = CFRunLoopObserverCreateWithHandler(kCFAllocatorSystemDefault, activitys.rawValue, repeatObserver, order) { ob, ac in
            callback(ac)
        }
        self.observer = ob
    }
    public func addRunloop(runloop:RunLoop,mode:RunLoop.Mode){
        CFRunLoopAddObserver(runloop.getCFRunLoop(), self.observer, CFRunLoopMode(mode.rawValue as CFString))
    }
    public func removeRunloop(runloop:RunLoop,mode:RunLoop.Mode){
        CFRunLoopRemoveObserver(runloop.getCFRunLoop(), self.observer, CFRunLoopMode(mode.rawValue as CFString))
    }
}
@resultBuilder public struct TaskBuild{
    public static func buildBlock(_ components: URLSessionTask...) -> [URLSessionTask] {
        return components
    }
    public static func buildOptional(_ component: [URLSessionTask]?) -> [URLSessionTask] {
        return component ?? []
    }
    public static func buildArray(_ components: [[URLSessionTask]]) -> [URLSessionTask] {
        return components.flatMap { i in
            return i
        }
    }
    public static func buildFinalResult(_ component: [URLSessionTask]) -> [Int] {
        return component.map{$0.taskIdentifier}
    }
    public static func buildEither(first component: [URLSessionTask]) -> [URLSessionTask] {
        return component
    }
    public static func buildEither(second component: [URLSessionTask]) -> [URLSessionTask] {
        return component
    }
}
