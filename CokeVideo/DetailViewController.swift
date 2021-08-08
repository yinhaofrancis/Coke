//
//  DetailViewController.swift
//  CokeVideo
//
//  Created by wenyang on 2021/8/1.
//

import UIKit

import Coke
class DetailCell: UITableViewCell {
    
    @IBOutlet weak var videoView: CokeView!
    override func awakeFromNib() {
        super.awakeFromNib()
        
        #if Coke
        if CokeView.useMetal{
            self.videoView.filter = CokeGaussBackgroundFilter(configuration: .defaultConfiguration)
        }else{
            self.videoView.filter = CokeGaussBackgroundFilter(configuration: .defaultConfiguration,imediately: false)
        }
        #else
        self.videoView.filter = CokeGaussBackgroundFilter(configuration: .defaultConfiguration,imediately: false)
        #endif
    }
}


class DetailViewController: UITableViewController {

    var model:[Model] = []
    var index:IndexPath?
    override func viewDidLoad() {
        super.viewDidLoad()
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
            if let id = self.index{
                self.tableView.scrollToRow(at: id, at: .middle, animated: false)
                self.playIndex(index: id)
            }
        }
        if #available(iOS 11.0, *) {
            self.tableView.contentInsetAdjustmentBehavior = .never
        } else {
            // Fallback on earlier versions
        }

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    // MARK: - Table view data source



    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return self.model.count
    }
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return self.view.frame.size.height
    }
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return self.view.frame.size.height
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell:DetailCell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! DetailCell
        cell.videoView.play(url: self.model[indexPath.row].url)
        return cell
    }
    override func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let cel = cell as! DetailCell
        cel.videoView.pause()
    }
    override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if decelerate == false {
            self.play()
        }else{
            scrollView.isScrollEnabled = false
        }
    }
    override func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        self.play()
    }
    override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.play()
    }
    func play(){
        self.tableView.isScrollEnabled = true
        guard let index = self.tableView.indexPathForRow(at: CGPoint(x: self.tableView.contentOffset.x, y: self.tableView.contentOffset.y + 1)) else { return }
        self.index = index
        self.playIndex(index: index)
    }
    func playIndex(index:IndexPath) {
        guard let cell = self.tableView.cellForRow(at: index) as? DetailCell else { return }
        cell.videoView.play()
    }
    
}
