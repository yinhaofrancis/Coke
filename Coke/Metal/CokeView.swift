//
//  File.swift
//  CokeVideo
//
//  Created by hao yin on 2021/2/25.
//

import Metal
import MetalKit
import Foundation
import UIKit
import AVFoundation

open class CokeView:UIView{
    public var videoLoader:CokeVideoLoader?
    
    public var player:CokeVideoPlayer?{
        get{
            self.videoLayer.cokePlayer
        }
        set{
            self.videoLayer.cokePlayer = newValue
        }
    }
    public var filter:CokeMetalFilter?{
        get{
            return self.videoLayer.videoFilter
        }
        set{
            self.videoLayer.videoFilter = newValue
        }
    }
    public override class var layerClass: AnyClass{
        if CokeView.memory() < 1200{
            return AVPlayerLayer.self
        }else{
            return CokeVideoLayer.self
        }
    }
    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.black
        self.videoLayer.basicConfig()
        
        self.filter = CokeGaussBackgroundFilter(configuration: .defaultConfiguration)

    }
    public static func systemCheck<T,W>(model1:Int32,model2:Int32,type:T.Type,map:((UnsafeMutablePointer<T>)->W))->W?{
        let model = UnsafeMutablePointer<Int32>.allocate(capacity: 2)
        model.assign(repeating: model1, count: 1)
        model.advanced(by: 1).assign(repeating: model2, count: 1)
        var count:Int = 1024
        let b = UnsafeMutableRawPointer.allocate(byteCount: 1024, alignment: 1)
        let rs = sysctl(model, 2, b, &count, nil, 0)
        if(rs == 0){
            return map(b.assumingMemoryBound(to: type))
        }
        return nil
    }
    public static func systemCheck(model1:Int32,model2:Int32)->String?{
        self.systemCheck(model1: model1, model2: model2, type: CChar.self) { t in
            String(cString: t)
        }
    }
    public static func memory() -> Double{
        var host_port:mach_port_t = 0
        var host_size:mach_msg_type_number_t = 0
        var pagesize:vm_size_t = 0
        host_port = mach_host_self();
        host_size = mach_msg_type_number_t(MemoryLayout<vm_statistics_data_t>.size / MemoryLayout<integer_t>.size)
        host_page_size(host_port, &pagesize);
        var vm_stat:vm_statistics_data_t = vm_statistics_data_t();
        let pointer = host_info_t.allocate(capacity: Int(host_size))
        if(host_statistics(host_port,HOST_VM_INFO, pointer, &host_size) != KERN_SUCCESS) {
            print("Failed to fetch vm statistics")
            
        }
        memcpy(&vm_stat, pointer, MemoryLayout.size(ofValue: vm_stat))
        let mem_used:natural_t = (vm_stat.active_count + vm_stat.inactive_count + vm_stat.wire_count) * UInt32(pagesize);
        let mem_free:natural_t = vm_stat.free_count * UInt32(pagesize);
        let mem_total:natural_t  = mem_used + mem_free;
        return Double(mem_total) / 1024.0 / 1024.0;
    }
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.backgroundColor = UIColor.black
        self.videoLayer.basicConfig()
    }
    public var videoLayer:CokeVideoDisplayer{
        return self.layer as! CokeVideoDisplayer
    }
    deinit {
        self.videoLayer.invalidate()
    }
    public func play(url:URL) {
        do {
            self.videoLoader = try CokeVideoLoader(url: url)
            guard let asset = self.videoLoader?.asset else { return }
            self.play(item: AVPlayerItem(asset: asset))
            
        } catch  {
            
        }
    }
    public func play(item:AVPlayerItem){
        self.player = CokeVideoPlayer(playerItem: item)
        self.player?.play()
    }
}

open class CokeVideoView<layer:CALayer & CokeVideoDisplayer>:UIView{
    public var videoLoader:CokeVideoLoader?
    
    public var player:CokeVideoPlayer?{
        get{
            self.videoLayer.cokePlayer
        }
        set{
            self.videoLayer.cokePlayer = newValue
        }
    }
    public var filter:CokeMetalFilter?{
        get{
            return self.videoLayer.videoFilter
        }
        set{
            self.videoLayer.videoFilter = newValue
        }
    }
    public override class var layerClass: AnyClass{
        return layer.self
    }
    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.black
        self.videoLayer.basicConfig()
        
        self.filter = CokeGaussBackgroundFilter(configuration: .defaultConfiguration)

    }
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.backgroundColor = UIColor.black
        self.videoLayer.basicConfig()
    }
    public var videoLayer:layer{
        return self.layer as! layer
    }
    deinit {
        self.videoLayer.invalidate()
    }
    public func play(url:URL) {
        do {
            self.videoLoader = try CokeVideoLoader(url: url)
            guard let asset = self.videoLoader?.asset else { return }
            self.play(item: AVPlayerItem(asset: asset))
            
        } catch  {
            
        }
    }
    public func play(item:AVPlayerItem){
        self.player = CokeVideoPlayer(playerItem: item)
        self.player?.play()
    }
}