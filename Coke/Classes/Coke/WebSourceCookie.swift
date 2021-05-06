//
//  WebSourceCookie.swift
//  test
//
//  Created by hao yin on 2021/4/15.
//

import Foundation

public class WebSourceCookie{
    public static var shared:WebSourceCookie = {
        try! WebSourceCookie(name:"default")
    }()
    private var filehandle:FileHandle?
    public init(name:String) throws {
        let dir = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let url = dir.appendingPathComponent(name).appendingPathExtension("dat")
        do {
            
            let cookieData = try Data(contentsOf: url)
            self.map = try JSONDecoder().decode([String:String].self, from: cookieData)
        } catch {
            self.map = [:]
            if(FileManager.default.fileExists(atPath: url.path)){
                try? FileManager.default.removeItem(at: url)
            }
            FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil)
        }
        self.filehandle = try FileHandle(forWritingTo: url)
    }
    private var map:[String:String]
    public subscript(url:URL)->String?{
        get{
            return map[url.host ?? ""]
        }
        set{
            guard let host = url.host else { return }
            map[host] = newValue
            self.SyncDisk()
        }
    }
    public func loadCookie(request:URLRequest)->URLRequest{
        var req = request
        guard let url = req.url else { return req}
        req.setValue(self[url], forHTTPHeaderField: "Cookie")
        return req
    }
    public func saveCookie(response:HTTPURLResponse){
        guard let url = response.url else { return }
        self[url] = response.allHeaderFields["Set-Cookie"] as? String
    }
    public func SyncDisk(){
        DispatchQueue.global().async {
            do {
                let data = try JSONEncoder.init().encode(self.map)
                self.filehandle?.write(data)
            } catch  {
                print(error)
            }
        }
    }
}
