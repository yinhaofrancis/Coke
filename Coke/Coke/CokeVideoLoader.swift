//
//  WebVideoLoader.swift
//  WebSource
//
//  Created by hao yin on 2021/5/2.
//

import Foundation
import UIKit
import AVFoundation

public class CokeVideoLoader:NSObject,AVAssetResourceLoaderDelegate{
    public var downloader:CokeSessionDownloader
    
    public init(url:URL) throws {
        self.downloader = try CokeSessionDownloader(url: url)
        super.init()
        self.image(se: 3,6,9) { _ in }
    }
    public var asset:AVAsset?{
        var c = URLComponents(string: self.downloader.url.absoluteString)
        c?.scheme = "wvl"
        guard let url = c?.url else { return nil }
        let a = AVURLAsset(url: url)
        a.resourceLoader.setDelegate(self, queue: DispatchQueue(label: "CokeVideoLoader"))
        return a
    }
    public func image(se:TimeInterval...,callback:@escaping (CGImage?)->Void){
        guard let ass = self.asset else {
            DispatchQueue.main.async {
                callback(nil)
            }
            return
        }
        let times = se.map({NSValue(time: CMTime(seconds: $0, preferredTimescale: .max))})
        AVAssetImageGenerator(asset: ass).generateCGImagesAsynchronously(forTimes: times) { (t, i, tt, re, e) in
            DispatchQueue.main.async {
                callback(i)
            }
        }
    }
    public func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        DispatchQueue.global().async {
            if loadingRequest.contentInformationRequest != nil{
                self.loadFileType(request: loadingRequest,noRecall: false)
            }else{
                self.loadFileData(request: loadingRequest,noRecall: false)
            }
        }
        return true
    }
    public func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        guard let dataReq = loadingRequest.dataRequest else { return }
        if dataReq.requestsAllDataToEndOfResource{
            self.downloader.cancel(index: UInt64(dataReq.currentOffset))
        }else{
            self.downloader.cancel(range: UInt64(dataReq.requestedOffset)...UInt64(Int(dataReq.requestedOffset) + dataReq.requestedLength - 1))
        }
    }
    func loadFileData(request:AVAssetResourceLoadingRequest,noRecall:Bool) {
        guard let dataRequest = request.dataRequest else { return }
        if request.isFinished || request.isCancelled{
            return
        }
        if dataRequest.requestsAllDataToEndOfResource{
            if let data = self.downloader[UInt64(dataRequest.currentOffset)]{
                dataRequest.respond(with: data)
                request.finishLoading()
            }else{
                let n :UInt64 = UInt64(dataRequest.currentOffset + 1024 * 1024)
                let end = n > self.downloader.storage.size - 1 ? UInt64(self.downloader.storage.size - 1) : n
                CokeSession.shared.beginGroup {
                    try? self.downloader.download(range: UInt64(dataRequest.currentOffset) ... end)
                } notify: {
                    self.loadFileData(request: request,noRecall: true)
                }

            }
        }else{
            let count:Int = (dataRequest.requestedLength > 1024 * 1024) ? 1024 * 1024  : dataRequest.requestedLength
            
            let r = UInt64(dataRequest.requestedOffset) ... UInt64(count + Int(dataRequest.requestedOffset) - 1)
            if self.downloader.storage.complete(range: r){
                if let data = self.downloader.storage[r]{
                    dataRequest.respond(with: data)
                    request.finishLoading()
                }
            }else{
                CokeSession.shared.beginGroup {
                    try? self.downloader.download(range: r)
                } notify: {
                    self.loadFileData(request: request,noRecall: true)
                }
            }
        }
    }
    func loadFileType(request:AVAssetResourceLoadingRequest,noRecall:Bool) {
        if(self.downloader.storage.size > 0){
            request.contentInformationRequest?.contentLength = Int64(self.downloader.storage.size)
            if(self.downloader.storage.resourceType.contains("video")){
                let mp4 = self.downloader.storage.resourceType.contains("mp4")
                let mpeg = self.downloader.storage.resourceType.contains("mpeg")
                let mov = self.downloader.storage.resourceType.contains("quicktime")
                let m4v = self.downloader.storage.resourceType.contains("m4v")
                if mp4 || mpeg{
                    request.contentInformationRequest?.contentType = AVFileType.mp4.rawValue
                } else if mov {
                    request.contentInformationRequest?.contentType = AVFileType.mov.rawValue
                }else if m4v{
                    request.contentInformationRequest?.contentType = AVFileType.m4v.rawValue
                }else{
                    request.contentInformationRequest?.contentType = AVFileType.mp4.rawValue
                }
            }else{
                request.contentInformationRequest?.contentType = AVFileType.mp4.rawValue
            }
            
            request.contentInformationRequest?.isByteRangeAccessSupported = true
            request.finishLoading()
        }else{
            CokeSession.shared.beginGroup {
                self.downloader.prepare()
            } notify: {
                self.loadFileType(request: request,noRecall: true)
            }

        }
    }
}
