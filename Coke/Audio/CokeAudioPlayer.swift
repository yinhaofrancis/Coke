import Foundation
import AudioToolbox
import CoreMedia

public class CokeAudioPlayer {
    
    var  audioBasic:AudioStreamBasicDescription
    
    var  queue:AudioQueueRef?
    
    var  packetPerBuffer:UInt32 = 1024
    
    private var buffers:[AudioQueueBufferRef] = []
    
    private var allbuffer:[AudioQueueBufferRef] = []
    
    public var endCallBack:(()->Void)?
    
    public var isRuning:UInt32{
        return getProperty(value: UInt32(0)) { ioPropertyDataSize, outPropertyData in
            AudioQueueGetProperty(self.queue!, kAudioQueueProperty_IsRunning, outPropertyData, ioPropertyDataSize)
        }
    }
    
    public var volume:Float32{
        get{
            var value : AudioQueueParameterValue = 0
            AudioQueueGetParameter(self.queue!, kAudioQueueParam_Volume, &value)
            return value
        }
        set{
            AudioQueueSetParameter(self.queue!, kAudioQueueParam_Volume, newValue)
        }
    }

    
    
    public var playRate:Float32{
        get{
            var value : AudioQueueParameterValue = 0
            AudioQueueGetParameter(self.queue!, kAudioQueueParam_PlayRate, &value)
            return value
        }
        set{
            AudioQueueSetParameter(self.queue!, kAudioQueueParam_PlayRate, newValue)
        }
    }
    public var pitch:Float32{
        get{
            var value : AudioQueueParameterValue = 0
            AudioQueueGetParameter(self.queue!, kAudioQueueParam_Pitch, &value)
            return value
        }
        set{
            AudioQueueSetParameter(self.queue!, kAudioQueueParam_Pitch, newValue)
        }
    }
 
    public var volumeRampTime:Float32{
        get{
            var value : AudioQueueParameterValue = 0
            AudioQueueGetParameter(self.queue!, kAudioQueueParam_VolumeRampTime, &value)
            return value
        }
        set{
            AudioQueueSetParameter(self.queue!, kAudioQueueParam_VolumeRampTime, newValue)
        }
    }
    
    public var pan:Float32{
        get{
            var value : AudioQueueParameterValue = 0
            AudioQueueGetParameter(self.queue!, kAudioQueueParam_Pan, &value)
            return value
        }
        set{
            AudioQueueSetParameter(self.queue!, kAudioQueueParam_Pan, newValue)
        }
    }
    
    public func play(data:Data){
        self.endCallBack = nil
        if(data.count == 0){
            return
        }
        var cur:Int64 = 0
        while(cur < data.count){
            if(cur + Int64(self.bufferSize) < data.count){
                self.playManagedData(data: data[cur ..< cur + Int64(self.bufferSize)])
            }else{
                self.playManagedData(data: data[Data.Index(cur) ..< data.count])
            }
            cur += Int64(self.bufferSize)
        }
    }
    public func stop(inImmediate:Bool = false,callback:@escaping ()->Void = {}){
        self.endCallBack = callback
        AudioQueueStop(self.queue!,inImmediate)
        
    }
    public func pause(){
        AudioQueuePause(self.queue!)
    }
    
    public func reset(){
        AudioQueueReset(self.queue!)
    }
    
    private func loadAudioBuffer(_ buffer: AudioQueueBufferRef,_ data:Data) {
        guard let queue = self.queue else { return }
        buffer.pointee.mAudioDataByteSize = UInt32(data.count)
        let buff:UnsafeMutablePointer<UInt8> = (buffer.pointee.mAudioData.bindMemory(to: UInt8.self, capacity: data.count))
        data.copyBytes(to:buff , count: data.count)
        AudioQueueEnqueueBuffer(queue, buffer, 0, nil)
        AudioQueueStart(queue, nil)
    }
    
    private func playManagedData(data:Data){
        CokeAudioPlayer.queue.async {
            if let buffer = self.buffers.first{
                self.loadAudioBuffer(buffer,data)
            }else{
                var buffer:AudioQueueBufferRef?
                AudioQueueAllocateBuffer(self.queue!, UInt32(data.count), &buffer)
                
                if let buffer{
                    self.allbuffer.append(buffer)
                    self.loadAudioBuffer(buffer,data)
                }
            }
        }
    }
    public var bufferSize:UInt32{
        (self.audioBasic.mBytesPerPacket) * self.packetPerBuffer
    }
    public var framesPerBuffer:UInt32{
        return (self.audioBasic.mFramesPerPacket) * self.packetPerBuffer
    }
    
    public init(audioDiscription: AudioStreamBasicDescription = CokeAudioConfig.shared.pcmAudioStreamBasicDescription,
                packPerBuffer:UInt32 = 1024) throws{
        var desc = audioDiscription
        var tempQueue:AudioQueueRef?
        self.packetPerBuffer = packPerBuffer
        self.audioBasic = desc
        let result = AudioQueueNewOutputWithDispatchQueue(&tempQueue, &desc, 0, CokeAudioPlayer.queue, {[weak self] queue, buffer in
            guard let self  else { return  }
            self.buffers.append(buffer)
        })
        if(result != errSecSuccess){
            throw NSError(domain: "播放器启动失败", code: Int(result))
        }
        self.queue = tempQueue
    }
    deinit{
        guard let queue else { return }
        if (self.isRuning != 0){
            self.stop(inImmediate: true)
        }
        self.allbuffer.forEach { b in
            AudioQueueFreeBuffer(queue, b)
        }
        AudioQueueDispose(queue, false)
    }
    
    public static let queue:DispatchQueue = DispatchQueue(label: "AudioPlayer")
}






public protocol CokeAudioRecoderOutput:AnyObject{
    func handle(recorder:CokeAudioRecorder,output:CokeAudioOutputBuffer)
}



public class CokeAudioRecorder{
    
    
    public weak var output:CokeAudioRecoderOutput?
    
    public static let queue:DispatchQueue = DispatchQueue(label: "AudioPlayer",attributes: .concurrent)
    
    
    public private(set) var audioStreamBasicDescription:AudioStreamBasicDescription

    private var audioQueue:AudioQueueRef?
    
    private var buffers:[AudioQueueBufferRef] = []
    
    public let bufferCount = 20
    
    public let sampleNum:UInt32 = 1024
    
    public var endCallBack:(()->Void)?
    
    private var isDestroyed:Bool = false
    
    public var bufferSize:UInt32 {
        
        self.audioStreamBasicDescription.mBytesPerPacket * sampleNum
    };
    public var isRuning:UInt32{
        return getProperty(value: UInt32(0)) { ioPropertyDataSize, outPropertyData in
            AudioQueueGetProperty(self.audioQueue!, kAudioQueueProperty_IsRunning, outPropertyData, ioPropertyDataSize)
        }
    }
    public init(audioStreamBasicDescription:AudioStreamBasicDescription = CokeAudioConfig.shared.pcmAudioStreamBasicDescription) throws{
        self.audioStreamBasicDescription = audioStreamBasicDescription
        AudioQueueNewInputWithDispatchQueue(&self.audioQueue, &self.audioStreamBasicDescription, 0, CokeAudioRecorder.queue) {[weak self] queue, buffer, time, numOfPack, packs in
            guard let self else { return }
            if(packs == nil){
                let buffer = CokeAudioOutputBuffer(time: CMClockMakeHostTimeFromSystemUnits(time.pointee.mHostTime), data: Data(bytes: buffer.pointee.mAudioData, count: Int(buffer.pointee.mAudioDataBytesCapacity)), numberOfChannel: self.audioStreamBasicDescription.mChannelsPerFrame,  packetDescriptions: [], description: self.audioStreamBasicDescription)
                if time.pointee.mHostTime > 0{
                    self.output?.handle(recorder: self, output: buffer)
                }else{
                    self.endCallBack?()
                    self.endCallBack = nil
                }
            }else{
                let buffer = CokeAudioOutputBuffer(time: CMClockMakeHostTimeFromSystemUnits(time.pointee.mHostTime), data: Data(bytes: buffer.pointee.mAudioData, count: Int(buffer.pointee.mAudioDataBytesCapacity)), numberOfChannel: self.audioStreamBasicDescription.mChannelsPerFrame , packetDescriptions: (0 ..< numOfPack).map { i in
                    packs![Int(i)]
                }, description: self.audioStreamBasicDescription)
                if time.pointee.mHostTime > 0{
                    self.output?.handle(recorder: self, output: buffer)
                }else{
                    self.endCallBack?()
                    self.endCallBack = nil
                }
                
            }
            AudioQueueEnqueueBuffer(queue, buffer, 0, nil)
        }
        guard let audioQueue else { throw NSError(domain: "Audio Recorder fail", code: 0) }
        let buffers = (0 ..< bufferCount).map { _ in
            var audioQueueBufferRef:AudioQueueBufferRef?
            AudioQueueAllocateBuffer(audioQueue, self.bufferSize, &audioQueueBufferRef)
            AudioQueueEnqueueBuffer(audioQueue, audioQueueBufferRef!, 0, nil)
            return audioQueueBufferRef!
        }
        self.buffers = buffers
    }
    public func start(){
        if self.isRuning == 0 {
            self.endCallBack = nil
            AudioQueueStart(self.audioQueue!, nil)
        }
        
    }
    public func stop(inImmediate:Bool = false,complete:@escaping ()->Void = {}){
        
        if self.isRuning > 0 {
            self.endCallBack = complete
            AudioQueueStop(self.audioQueue!,inImmediate)
        }
    }

    public func pause(){
        
        AudioQueuePause(self.audioQueue!)
    }
    public func reset(){
        AudioQueueReset(self.audioQueue!)
    }
    deinit{
        guard let aq = self.audioQueue else { return }
        self.stop(inImmediate: false)
        AudioQueueFlush(aq)
        self.buffers.forEach { i in
            AudioQueueFreeBuffer(aq, i)
        }
        AudioQueueDispose(aq, false)
    }
}
