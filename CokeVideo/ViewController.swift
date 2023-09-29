//
//  ViewController.swift
//  Coke
//
//  Created by yinhaoFrancis on 05/02/2021.
//  Copyright (c) 2021 yinhaoFrancis. All rights reserved.
//

import UIKit
import AVFoundation
import Coke
import AVKit
import VideoToolbox
import Accelerate
import os
import rtmp

class Model:Codable{
    var name:String
    var url:URL
    var image:Data
    init(name:String,url:URL,image:Data) {
        self.name = name
        self.url = url
        self.image = image
    }
}
class ViewController: UITableViewController,UISearchBarDelegate {

    public var loader:CokeVideoLoader?
    public var track:CokeAssetVideoTrack?
    public var actions:[UITableViewRowAction]?
    public var data:[Model] = []
    public var url:URL?
    public var timer:Timer?
    public var window:UIWindow = UIWindow(frame: UIScreen.main.bounds)
    override func viewDidLoad() {
        super.viewDidLoad()
        self.window.makeKeyAndVisible()
        self.window.isUserInteractionEnabled = false;
        self.window.isHidden = false
        self.window.alpha = 1
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        do {
            let url = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("back")
            self.url = url
            if !FileManager.default.fileExists(atPath: url.path){
                FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil)
            }
            let data = try Data(contentsOf: url)
            if data.count == 0{
                DispatchQueue.main.async {
                    self.process(str: "http://www.heishenhua.com/video/b1/gamesci_2021.mp4")
                    self.process(str: "http://www.heishenhua.com/video/preview/video_Day1.mp4")
                    self.process(str: "http://www.heishenhua.com/video/preview/video_Day2.mp4")
                    self.process(str: "http://www.heishenhua.com/video/preview/video_Day3.mp4")
                    self.process(str: "http://www.heishenhua.com/video/preview/video_Day4.mp4")
                    self.process(str: "http://www.heishenhua.com/video/preview/video_Day5.mp4")
                    self.process(str: "http://www.heishenhua.com/video/preview/video_Day6.mp4")
                }
            }else{
                self.data = try JSONDecoder().decode([Model].self, from: data)
            }
        }catch{

        }
        self.actions = [
            UITableViewRowAction(style: .destructive, title: "删除") { (a, index) in
                if #available(iOS 11.0, *) {
                    self.tableView.performBatchUpdates {
                        let u = self.data.remove(at: index.row).url
                        self.tableView.deleteRows(at: [index], with: .automatic)
                        try? self.saveData()
                        try? CokeVideoLoader(url: u).downloader.storage.delete()
                    } completion: { (_) in

                    }
                } else {
                    let u = self.data.remove(at: index.row).url
                    self.tableView.reloadData()
                    try? self.saveData()
                    try? CokeVideoLoader(url: u).downloader.storage.delete()
                    // Fallback on earlier versions
                }
            },
            UITableViewRowAction(style: .normal, title: "复制") { (a, index) in
                let u = self.data[index.row].url
                UIPasteboard.general.url = u
            },
//            UITableViewRowAction(style: .normal, title: "下载") { (a, index) in
//                let u = self.data[index.row].url
//                self
//            },
            UITableViewRowAction(style: .normal, title: "Display") { (a, index) in
                let url = self.data[index.row].url
                self.loader = try? CokeVideoLoader(url: url)
                guard let ass = self.loader?.asset else { return }
                let a = AVPlayerViewController()
                CokeVideoPlayer.shared.replaceCurrentItem(with: AVPlayerItem(asset: ass))
                a.player = CokeVideoPlayer.shared
                DispatchQueue.main.async {
                    self.present(a, animated: true, completion: nil)
                    a.player?.play()
                }
            }
        ]

    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.data.count
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = self.data[indexPath.row].name
        cell.detailTextLabel?.text = self.data[indexPath.row].url.absoluteString
        cell.imageView?.image = UIImage(data: self.data[indexPath.row].image)
        return cell
    }
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        return self.actions
    }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let str = searchBar.text else { return  }
        self.process(str: str)
        self.tableView.reloadData()
        self.view.window?.endEditing(true)
        searchBar.text = nil
    }
    func process(str:String){
        let a = str.components(separatedBy: .whitespacesAndNewlines).map({URL(string: $0)}).compactMap({$0}).map { (u) -> Model in
            Model(name: "", url: u, image: Data())
        }

        a.map { (m) -> (CokeVideoLoader,Model)? in
            guard let l = try? CokeVideoLoader(url: m.url) else { return nil }
            return (l,m)
        }.compactMap({$0}).forEach { (i) in
            i.0.image(se: 1) { (img) in
                guard let ig = img else { return }
                guard let data = UIImage(cgImage: ig).jpegData(compressionQuality: 0.3) else { return }
                i.1.image = data
                self.tableView.reloadData()
                try? self.saveData()
            }
        }
        self.data.append(contentsOf: a)
        self.tableView.reloadData()

        try? self.saveData()
        self.view.window?.endEditing(true)
    }
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        self.view.window?.endEditing(true)
        searchBar.text = nil
        RunLoop.main.perform(inModes: [.init("CC")]) {
            print("CC")
        }
        RunLoop.main.perform(inModes: [.init("CC")]) {
            print("CC")
        }
        RunLoop.main.perform(inModes: [.init("CC")]) {
            print("CC")
        }
        RunLoop.main.perform(inModes: [.init("CC")]) {
            print("CC")
        }
        print("Cancel")
        RunLoop.main.run(mode: .init("CC"), before: Date(timeIntervalSinceNow: 100))

    }
    func saveData() throws{
        do {
            let data = try JSONEncoder().encode(self.data)
            guard let url = self.url else { throw NSError(domain: "error", code: 0, userInfo: nil) }
            try data.write(to: url)
        } catch  {
            throw error
        }
    }


    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "detail"{
            let des:DetailViewController = segue.destination as! DetailViewController
            des.model = self.data
            des.index = self.tableView.indexPathForSelectedRow
        }
    }
}


class CameraViewController:UIViewController{
    @IBOutlet public var video:CokeSampleView!
    public var cokeView:CokeView{
        return self.view as! CokeView
    }
    public var display:CokeVideoLayer{
        self.cokeView.videoLayer as! CokeVideoLayer
    }
    public var encode:CodeVideoEncoder?
    public var decode:CokeVideoDecoder?

    public var file:CokeFile?

    public lazy var camera:CokeCapture = {
        if self.encode == nil{

            self.encode = try? CodeVideoEncoder(width: 720, height: 1280)
            self.encode?.setBframe(bframe: true)
            if #available(iOS 15.0, *) {
                self.encode?.setMaxAllowQP(qp: 0.3)
            } else {
                self.encode?.setQuality(quality: 0.3)
            }

            self.encode?.setProfileLevel(value: kVTProfileLevel_H264_Main_AutoLevel)
            self.encode?.setMaxKeyFrameInterval(maxKeyFrameInterval: 60)
            self.encode?.setColorSpace(vcs: .VCS_2100_HLG)
//            self.encode?.setAverageBitRate(averageBitRate: 1024 * 1024 * 8)
//            if #available(iOS 15.0, *) {
//                self.encode?.setMaxAllowQP(qp: 0.6)
//            } else {
//                // Fallback on earlier versions
//            }
//            if #available(iOS 16.0, *) {
//                self.encode?.setMinAllowQP(qp: 0.1)
//            } else {
//                // Fallback on earlier versions
//            }
//            self.encode?.setAverageBitRate(averageBitRate: 1)
//            self.encode?.setFrameRate(frameRate: 1)
        }
        return try! CokeCapture{[weak self] sample in


            if let buffer = VideoEncoderBuffer(sample: sample)  {

                self?.encode?.encode(buffer: buffer, callback: { i, f, e, index in
                    guard let e else { return }
                    AppDelegate.video.append(e);
                    print(sample.presentationTimeStamp.seconds,"v \(e.isIFrame) \(e.dataBuffer?.dataLength)")
                })
                guard let px = sample.imageBuffer else { return }
                DispatchQueue.main.async {
                    self?.display.render(pixelBuffer: px)
                }
            }else{

                AppDelegate.audio.append(sample);
                print(sample.presentationTimeStamp.seconds,"a \(sample.dataBuffer?.dataLength)")
            }

        }
    }()
    override func viewDidLoad() {
        super.viewDidLoad()

        AppDelegate.video.removeAll()
        AppDelegate.audio.removeAll()
        self.display.videoFilter = CokeGaussBackgroundFilter(configuration: .defaultConfiguration)

        self.camera.start()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

    }
    deinit{
        self.camera.stop()
        if(AppDelegate.video.count > 0 && AppDelegate.audio.count > 0){
            let url = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("a.mp4")
            let f = try! CokeFile(url: url.absoluteString, videoFormat: AppDelegate.video.first!.formatDescription!, audioFormat: AppDelegate.audio.first!.formatDescription!)
            f.queue.async {
                AppDelegate.video.forEach { c in
                    f.write(sample: c)
                }
                AppDelegate.audio.forEach { c in
                    f.write(sample: c)
                }
                f.finish()
            }
        }
    }
}



class outViewController:UIViewController,CokeAudioRecoderOutput{

    func handle(recorder: Coke.CokeAudioRecorder, output: Coke.CokeAudioOutputBuffer) {

        guard let out = encoder?.encode(buffer: output) else { return }
        
        guard let out2 = self.decoder?.decode(buffer: out) else { return }
        self.buffer.append(out2)
        print(output.data.count,out.data.count,out2.data.count)
    }


    public var render:CokeSampleView{
        return self.view as! CokeSampleView
    }

    let b = UIButton(type: .close)

    public var buffer:[CokeAudioOutputBuffer] = []
    public var player:CokeAudioPlayer?
    public var recoder:CokeAudioRecorder?
    public var encoder:CokeAudioConverter?
    public var decoder:CokeAudioConverter?
    override func viewDidLoad() {
        super.viewDidLoad()
        self.recoder = try! CokeAudioRecorder()
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        self.recoder?.output = self
        self.encoder = try? CokeAudioConverter(encode: self.recoder!.audioStreamBasicDescription)
        self.encoder?.bitRate = 96000
        self.decoder = try? CokeAudioConverter(decode: self.encoder!.destination,mChannelsPerFrame: 1)
        self.player = try! CokeAudioPlayer(audioDiscription: self.decoder!.destination)
        b.frame = CGRect(x: 0, y: 200, width: 88, height: 88)

        self.view .addSubview(b)
        self.view.addConstraints([
            b.centerXAnchor .constraint(equalTo: self.view.centerXAnchor),
            b.centerYAnchor .constraint(equalTo: self.view.centerYAnchor),
        ])
        b.addConstraints([
            b.widthAnchor .constraint(equalToConstant: 88),
            b.heightAnchor .constraint(equalToConstant: 88),
        ])
        b.translatesAutoresizingMaskIntoConstraints = false;
        b .addTarget(self, action: #selector(down), for: .touchDown)
        b .addTarget(self, action: #selector(up), for: .touchUpInside)

        if(AppDelegate.video.count > 0 && AppDelegate.audio.count > 0){
            if AppDelegate.video.first!.presentationTimeStamp < AppDelegate.audio.first!.presentationTimeStamp {
                self.render.sync.setRate(1, time: AppDelegate.video.first!.presentationTimeStamp)
            }else{
                self.render.sync.setRate(1, time: AppDelegate.audio.first!.presentationTimeStamp)
            }
            AppDelegate.video.forEach { buf in
                self.render.enqueue(sample: buf)
            }
            AppDelegate.audio.forEach { buf in
                self.render.enqueue(sample: buf)
            }
        }
    }
    @objc func down(){
        self.buffer.removeAll()
        self.encoder?.reset()
        self.decoder?.reset()
        self.player = try! CokeAudioPlayer(audioDiscription: self.decoder!.destination)
//        self.recoder?.reset()

        try? AVAudioSession.sharedInstance().setCategory(.record)
        self.recoder?.start()
    }
    @objc func up(){
        self.recoder?.stop(complete: {
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            let data = self.buffer.reduce(into: Data(), { partialResult, b in
                partialResult += b.data
            })
            self.player?.play(data: data)
        })
    }
}

public class render2dViewController:UIViewController{
    let coke = try! Coke2D(w: 100, h: 100)
    var texture:MTLTexture?
    lazy var po = try! Population(count: 60, coke: self.coke, filterSource: UIImage(named: "icon")!.cgImage!)
    public override func viewDidLoad() {
        super.viewDidLoad()

        self.view.layer.addSublayer(coke.layer)
        coke.layer.frame.origin = CGPoint(x: 100, y: 100)
        FrameTicker.shared.addCallback(sender: self, sel: #selector(render))
    }
    lazy var out = try! self.coke.createTexture(w: self.coke.width, h: self.coke.height)
    lazy var diffout = try! self.coke.createTexture(w: self.coke.width, h: self.coke.height)
//    lazy var diff = try! ComputeDiff(coke: self.coke, cg: UIImage(named: "icon")!.cgImage!, type: .hamming)
//    lazy var sum = try! ComputeSum(coke: self.coke)
    lazy var popu = Population.parse(coke: self.coke, filterSource: UIImage(named: "icon")!.cgImage!)
    @objc public func render(){
        try! popu.filter()
        for i in popu.gens{
            let g = try! i.path(coke: self.coke)
            let b = try! self.coke.begin()
            try! self.coke.draw(buffer: b) { e in
                g.draw(encode: e)
            }
            self.coke.commit(buffer: b)
        }
        let score = self.popu.gens.first!.score
        RunLoop.main.perform {
            self.title = "\(score)"
        }
    }
}
