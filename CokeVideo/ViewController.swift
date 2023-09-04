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
import Accelerate

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
    
    fileprivate func imageShow(_ vc: CokePlayerViewController) {
        DispatchQueue.global().async {
            let data = try! Data(contentsOf: URL(string: "https://gimg2.baidu.com/image_search/src=http%3A%2F%2Fpayposter.com%2Fposter_preview%2F1920x1200-hd-48029943.jpg&refer=http%3A%2F%2Fpayposter.com&app=2002&size=f9999,10000&q=a80&n=0&g=0n&fmt=jpeg?sec=1630144314&t=31bae1063c7752ea541f3f1d97b08c64")!)
            DispatchQueue.main.async {
                vc.showImage(data: data)
            }
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
    
    public var cokeView:CokeView{
        return self.view as! CokeView
    }
    public var display:CokeVideoLayer{
        self.cokeView.videoLayer as! CokeVideoLayer
    }
    public var encode:CodeVideoEncode?
    public lazy var camera:CokeCapture = {
        CokeCapture(preset: .hd4K3840x2160) {[weak self] sample in
            if self?.encode == nil{
                
                self?.encode = try? CodeVideoEncode(width: Int32(sample.width), height: Int32(sample.height))
            }
            guard let buffer = VideoEncoderBuffer(sample: sample) else {
                return
            }
//            self?.encode?.encode(buffer: buffer, callback: { i, f, e, i in
////                print(e as Any);
//            })
            guard let px = sample.imageBuffer else { return }
            DispatchQueue.main.async {
                self?.display.render(pixelBuffer: px, transform: CGAffineTransformMakeRotation(.pi / 2))
            }
        }
    }()
    override func viewDidLoad() {
        super.viewDidLoad()
        self.display.videoFilter = CokeGaussBackgroundFilter(configuration: .defaultConfiguration)
        
        self.camera.start()
    }
}

