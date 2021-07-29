//
//  CokeVideoPlayer.swift
//  CokeVideo
//
//  Created by hao yin on 2021/3/2.
//

import UIKit
import AVFoundation

public class CokeVideoPlayer:AVPlayer{
    private var lastPixelBuffer:CVPixelBuffer?
    public var output = AVPlayerItemVideoOutput(pixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String:CokeConfig.videoColorFormat,
        kCVPixelBufferMetalCompatibilityKey as String:true
        
    ])
    public var currentPresentTransform:CGAffineTransform = .identity
    public override func play() {
        if let ass = self.currentItem?.asset{
            ass.loadValuesAsynchronously(forKeys: ["tracks","playable"], completionHandler: {
                if ass.statusOfValue(forKey: "tracks", error: nil) == .loaded{
                    if let tracks = ass.tracks(withMediaType: .video).first{
                        tracks.loadValuesAsynchronously(forKeys: ["preferredTransform"]) {
                            if(tracks.statusOfValue(forKey: "preferredTransform", error: nil) == .loaded){
                                self.currentPresentTransform = tracks.preferredTransform
                                self.currentItem?.add(self.output)
                                super.play()
                                if(tracks.statusOfValue(forKey: "playable", error: nil) == .loaded && ass.isPlayable){
                                    super.play()
                                }
                            }
                        }
                    }
                }
            })
        }
        
    }
    
    public func copyPixelbuffer()->CVPixelBuffer?{
        if let time = self.currentItem?.currentTime(), self.output.hasNewPixelBuffer(forItemTime: time){
            var ptime = CMTime.zero
            self.lastPixelBuffer = self.output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: &ptime);
            return self.lastPixelBuffer
        }
        return nil
    }
    public var percent:Double{
        get{
            Double((self.currentTime() ).seconds / (self.currentItem?.duration.seconds ?? 1))
        }
        set{
            guard let sec = self.currentItem?.duration.seconds else { return }
            let step = self.currentItem?.duration.seconds ?? 0 / 100.00
            self.seek(to:CMTime(seconds: newValue * sec, preferredTimescale: .max), toleranceBefore: CMTime(seconds: step, preferredTimescale: .max), toleranceAfter: CMTime(seconds: step, preferredTimescale: .max), completionHandler: { b in
                
            })
        }
    }
    
}
