//
//  CokeGallery.swift
//  Coke
//
//  Created by hao yin on 2021/6/1.
//

import Foundation
import Photos
import PhotosUI

public class CokePhoto{
    public func assetCollections(type:PHAssetCollectionType,subtype:PHAssetCollectionSubtype)->PHFetchResult<PHAssetCollection> {
        PHAssetCollection.fetchAssetCollections(with: type, subtype: subtype, options: nil)
    }
    public func collectionList(type:PHCollectionListType,subtype:PHCollectionListSubtype)->PHFetchResult<PHCollectionList>{
        PHCollectionList.fetchCollectionLists(with: type, subtype: subtype, options: nil)
    }
    public func asset(collection:PHAssetCollection? = nil)->PHFetchResult<PHAsset>{
        if let c = collection{
            return PHAsset.fetchAssets(in: c, options: nil)
        }else{
            return PHAsset.fetchAssets(with: nil)
        }
    }
    public func asset(type:PHAssetMediaType)->PHFetchResult<PHAsset>{
        PHAsset.fetchAssets(with: type, options: nil)
    }
    public func resource(asset:PHAsset)->[PHAssetResource]{
        return PHAssetResource.assetResources(for: asset)
    }
    public func resource(asset:PHAsset,type:PHAssetResourceType)->PHAssetResource?{
        return PHAssetResource.assetResources(for: asset).filter{$0.type == type}.first
    }
    public func copyResource(resource:PHAssetResource,callback:@escaping (URL?)->Void){
        let u = FileManager.default.temporaryDirectory.appendingPathExtension("\(arc4random())")
        self.resource.writeData(for: resource, toFile: u, options: nil) { e in
            if e == nil{
                callback(u)
            }else{
                callback(nil)
            }
        }
        
    }
    public class func requestRequest(callback:@escaping (PHAuthorizationStatus)->Void){
        if self.currentState == .authorized{
            callback(self.currentState)
        }else{
            if #available(iOS 14, *) {
                PHPhotoLibrary.requestAuthorization(for: .readWrite, handler: callback)
            } else {
                PHPhotoLibrary.requestAuthorization(callback)
            }
        }
    }
    public static var currentState:PHAuthorizationStatus{
        if #available(iOS 14, *) {
            return PHPhotoLibrary.authorizationStatus(for: .readWrite)
        } else {
            return PHPhotoLibrary.authorizationStatus()
        }
    }
    public var resource:PHAssetResourceManager = PHAssetResourceManager()
    
    public static var shared:CokePhoto = {
        return CokePhoto()
    }()
}

public class CokePhotoView:UICollectionView,UICollectionViewDelegate,UICollectionViewDataSource{
    
    public var assets:PHFetchResult<PHAsset>?{
        didSet{
            self.layout?.itemSize = CGSize(width: self.frame.size.width / 3 - 2, height: self.frame.size.width / 3 - 2)
            self.layout?.minimumLineSpacing = 2
            self.layout?.minimumInteritemSpacing = 0
            self.reloadData()
        }
    }
    public override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: layout)
    }
    public init(frame: CGRect) {
        let l = UICollectionViewFlowLayout()
        l.itemSize = CGSize(width: 128, height: 128)
        super.init(frame: frame, collectionViewLayout: l)
    }
    public var layout:UICollectionViewFlowLayout?{
        return self.collectionViewLayout as? UICollectionViewFlowLayout
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    private var manager:PHCachingImageManager = PHCachingImageManager()
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        self.register(CokePhotoCell.self, forCellWithReuseIdentifier: "Cell")
        self.delegate = self
        self.dataSource = self
    }
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return assets?.count ?? 0
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! CokePhotoCell
        self.manager.requestImage(for: self.assets![indexPath.row], targetSize: CGSize(width: 128, height: 128), contentMode: .aspectFill, options: nil) { i, dic in
            cell.thumbnail.image = i
        }
        return cell
    }
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let ass = self.assets![indexPath.row]
        if(ass.mediaType == .video){
            self.manager.requestPlayerItem(forVideo: ass, options: nil) { item, dic in
                self.playCallback?(item)
            }
        }else if (ass.mediaType == .image){
            self.manager.requestImageData(for: ass, options: nil) { data, str, or, dic in
                guard let dat = data else { self.imageCallback?(nil);return }
                let img = UIImage(data: dat)
                self.imageCallback?(img)
            }
        }else{
            self.callback?(ass)
        }
    }
    public var playCallback:((AVPlayerItem?)->Void)?
    public var imageCallback:((UIImage?)->Void)?
    public var callback:((PHAsset)->Void)?
}

public class CokePhotoCell:UICollectionViewCell{
    public var thumbnail:UIImageView
    public override init(frame: CGRect) {
        thumbnail = UIImageView(frame: frame)
        super.init(frame: frame)
        self.contentView.addSubview(thumbnail)
        thumbnail.contentMode = .scaleAspectFill
        thumbnail.clipsToBounds = true
        thumbnail.translatesAutoresizingMaskIntoConstraints = false;
        let a = [
            thumbnail.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor),
            thumbnail.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor),
            thumbnail.topAnchor.constraint(equalTo: self.contentView.topAnchor),
            thumbnail.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor)
        ]
        self.contentView .addConstraints(a)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
