//
//  CokeVideoGallery.swift
//  CokeVideo_Example
//
//  Created by hao yin on 2021/3/20.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import Foundation
import Photos

public class CokeVideoGallery{
    class public func saveVideo(url:URL,callback:@escaping (String?)->Void){
        
        var id:String?
        PHPhotoLibrary.shared().performChanges {
            let change = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            let placehold = change?.placeholderForCreatedAsset
            id = placehold?.localIdentifier
        } completionHandler: { (b, e) in
            DispatchQueue.main.async {
                callback(id)
            }
        }
    }
}
