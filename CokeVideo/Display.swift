//
//  ContentView.swift
//  m
//
//  Created by wenyang on 2023/9/28.
//

import SwiftUI
import SwiftData
import AVFoundation

struct ContentView: View {
    var body: some View {
        Text("dadas")
    }
}

struct ProgressBar:View {
   
    @Binding var percent:Float
    
    @State private var onTouch:Bool = false
    
    public var didChange:()->Void
    
    var body: some View {
        GeometryReader(content: { geometry in
            ZStack(alignment:Alignment(horizontal: .leading, vertical: .center)){
                Rectangle().fill(Color.gray).frame(minWidth: 40, maxWidth:.infinity ,maxHeight: 2 ,alignment: .leading)
                Rectangle().fill(Color.red).frame(width: geometry.size.width * CGFloat(self.percent), height: 2)
                Circle().fill(self.onTouch ? Color.white : Color.clear).frame(width: 20,height: 20).offset(CGSize(width: geometry.size.width * CGFloat(self.percent) - CGFloat(20 * self.percent), height: 0)).shadow(radius: 3)
            }.gesture(DragGesture(coordinateSpace: .local).onChanged({ v in
                self.onTouch = true
                self.percent = self.claim(v: Float(v.location.x / geometry.size.width))
                self.didChange()
            }).onEnded({ v in
                self.onTouch = false
                self.percent = self.claim(v: Float(v.location.x / geometry.size.width))
                self.didChange()
            })).frame(minHeight: 44)
        })
    }
    func claim(v:Float)->Float{
        v < 0 ? 0 : (v > 1 ? 1 : v)
    }

}

struct VideoTimeProcessBar:View {
    public var end:Date
    @State var current:Date
    @State var percent:Float
    public var didChange:()->Void
    var body: some View {
        HStack(alignment: .center){
            Text(self.dateString(date: self.current)).font(.system(size: 8)).frame(width: 30)
            ProgressBar(percent: $percent){
                self.current = Date(timeIntervalSince1970: Double(percent) * end.timeIntervalSince1970)
                self.didChange()
            }
            Text(self.dateString(date: self.end)).font(.system(size: 8)).frame(width: 30)
        }.frame(height: 44)
    }
    public func dateString(date:Date)->String{
        VideoTimeProcessBar.format.string(from: date)
    }
    public static var format:DateFormatter = {
       let df = DateFormatter()
        df.dateFormat = "mm:ss"
        df.timeZone = TimeZone(secondsFromGMT: 0)
        return df
    }()
    init(end: Date,percent:Float, didChange: @escaping () -> Void) {
        self._percent = State(initialValue: percent)
        self._current = State(initialValue: Date(timeIntervalSince1970: Double(percent) * end.timeIntervalSince1970))
        self.end = end
        self.didChange = didChange
    }
}

class ViewDisplayUIView:UIView{
    override class var layerClass: AnyClass{
        AVPlayerLayer.self
    }
}

struct VideoDisplay:UIViewRepresentable{
    var player:AVPlayer?
    var view = ViewDisplayUIView()
    func makeUIView(context: Context) -> ViewDisplayUIView {
        
        return view
    }
    
    func updateUIView(_ uiView: ViewDisplayUIView, context: Context) {
        
    }
    
    typealias UIViewType = ViewDisplayUIView
    
    
}


