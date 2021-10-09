//
//  CokeTask.swift
//  Coke
//
//  Created by hao yin on 2021/9/29.
//

import Foundation
import BackgroundTasks


@available(iOS 13.0, *)
public class CokeRefreshTask{
    public var task:BGAppRefreshTask?
    public var queue:DispatchQueue
    public var earlyDate:TimeInterval
    public var name:String
    public init(name:String,queue:DispatchQueue = DispatchQueue.global(),earlyDate:TimeInterval = 1 * 60){
        self.queue = queue
        self.name = name
        self.earlyDate = earlyDate
    }
    public func schedule(){
        BGTaskScheduler.shared.register(forTaskWithIdentifier: name, using: self.queue) { [weak self] tk in
            guard let ws = self else { return }
            self!.task = tk as? BGAppRefreshTask
            ws.run()
        }
    }
    public func request(){
        let request = BGAppRefreshTaskRequest(identifier: self.name)
        request.earliestBeginDate = Date(timeIntervalSinceNow: self.earlyDate)
        do{
            try BGTaskScheduler.shared.submit(request)
            
        }catch{
            print(error)
        }
    }
    public func run(){
        self.queue.asyncAfter(deadline: .now() + .seconds(2)) {
            self.task?.setTaskCompleted(success: true)
            #if DEBUG
            print("end")
            #endif
        }
        
    }
}
