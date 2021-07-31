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
    public var actions:[UITableViewRowAction]?
    public var data:[Model] = []
    public var url:URL?
    public var timer:Timer?
    public var window:UIWindow = UIWindow(frame: UIScreen.main.bounds)
    public var dlayler:AVPlayerLayer = AVPlayerLayer()
    public var player:AVPlayer?
    override func viewDidLoad() {
        super.viewDidLoad()
        self.window.makeKeyAndVisible()
        self.window.isUserInteractionEnabled = false;
        self.window.layer.addSublayer(dlayler)
        self.window.isHidden = false
        self.window.alpha = 1
        dlayler.frame = UIScreen.main.bounds
        do {
            let url = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("back")
            self.url = url
            if !FileManager.default.fileExists(atPath: url.path){
                FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil)
            }
            let data = try Data(contentsOf: url)
            self.data = try JSONDecoder().decode([Model].self, from: data)
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
            UITableViewRowAction(style: .normal, title: "下载") { (a, index) in
                let u = self.data[index.row].url
                try? CokeVideoLoader(url: u).downloader.download {
                    
                }
            },
            UITableViewRowAction(style: .normal, title: "Display") { (a, index) in
                let u = self.data[index.row].url
                let i = AVPlayerItem(asset: AVAsset(url: u))
                self.player = AVPlayer(playerItem: i)
                self.dlayler.player = self.player
                self.player?.play()
                
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
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let vc:CokePlayerViewController = self.storyboard?.instantiateViewController(withIdentifier: "player") as! CokePlayerViewController
        self.imageShow(vc)
        DispatchQueue.main.async {
            vc.play(url: self.data[indexPath.row].url)
        }
        self.show(vc, sender: nil)
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
    
    @IBAction func show(_ sender: Any) {
        let vc:CokePlayerViewController = self.storyboard?.instantiateViewController(withIdentifier: "player") as! CokePlayerViewController
        
        self.show(vc, sender: nil)
        imageShow(vc)
    }
}

