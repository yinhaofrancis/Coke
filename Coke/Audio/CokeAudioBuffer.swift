//
//  File.swift
//
//
//  Created by wenyang on 2023/7/2.
//

import AudioToolbox
import AVFoundation

public struct AudioOutBufferPacket{
    
    public var data:Data
    
    public var audioStreamPacketDescription:AudioStreamPacketDescription
    
    public init(data: Data, audioStreamPacketDescription: AudioStreamPacketDescription) {
        self.data = data
        self.audioStreamPacketDescription = audioStreamPacketDescription
    }
}

public struct AudioOutBuffer{
    
    public var packets:[AudioOutBufferPacket]
    
    public var audioStreamBasicDescription:AudioStreamBasicDescription
    
    public init(packets: [AudioOutBufferPacket], audioStreamBasicDescription: AudioStreamBasicDescription) {
        self.packets = packets
        self.audioStreamBasicDescription = audioStreamBasicDescription
    }
}

public protocol AudioDecode{
    func decode(audioPackets:[Data])->Data
}

public protocol AudioEncode{
    func encode(pcmBuffer:Data)->AudioOutBuffer
}

public func getProperty<T>(value:T,callback:(_ ioPropertyDataSize: UnsafeMutablePointer<UInt32>,_ outPropertyData: UnsafeMutableRawPointer)->Void)->T{
    var size:UInt32 = UInt32(MemoryLayout<T>.size)
    var valuet = value
    callback(&size,&valuet)
    return valuet
}

public func setProperty<T>(value:T,callback:(_ inPropertyDataSize: UInt32, _ inPropertyData: UnsafeRawPointer)->Void){
    let size:UInt32 = UInt32(MemoryLayout<T>.size)
    var valuet = value
    callback(size,&valuet)
}


extension CMSampleBuffer {
    var pcm:Data?{

        guard self.mediaType == kCMMediaType_Audio else {
            return nil
        }
        return try? self.dataBuffer?.dataBytes()
    }
}

