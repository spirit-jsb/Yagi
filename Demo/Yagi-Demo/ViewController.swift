//
//  ViewController.swift
//  Yagi-Demo
//
//  Created by max on 2020/9/12.
//  Copyright © 2020 max. All rights reserved.
//

import UIKit
import PhotosUI
import Yagi

class ViewController: UIViewController {
  
  private let photoLibrary = PHPhotoLibrary.shared()
  
  private lazy var pickerConfiguration: PHPickerConfiguration = {
    var pickerConfiguration = PHPickerConfiguration(photoLibrary: self.photoLibrary)
    pickerConfiguration.selectionLimit = 1
    pickerConfiguration.filter = PHPickerFilter.videos
    return pickerConfiguration
  }()
  
  private lazy var pickerViewController: PHPickerViewController = {
    let pickerViewController = PHPickerViewController(configuration: self.pickerConfiguration)
    pickerViewController.delegate = self
    return pickerViewController
  }()

  override func viewDidLoad() {
    super.viewDidLoad()
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
  }
  
  @IBAction func triggerChooseVideo(_ sender: UIBarButtonItem) {
    self.present(self.pickerViewController, animated: true, completion: nil)
  }
}

extension ViewController: PHPickerViewControllerDelegate {
  
  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true, completion: nil)
    
    let identifiers = results.compactMap(\.assetIdentifier)
    let fetchResults = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        
    print("\(identifiers) \(fetchResults)")
    [
      VMAssetExportSession.Preset.VMAssetExportPreset1080p,
      VMAssetExportSession.Preset.VMAssetExportPreset720p,
      VMAssetExportSession.Preset.VMAssetExportPreset480p,
      VMAssetExportSession.Preset.VMAssetExportPreset360p
    ].forEach({ (preset) in
      
    })
  }
}
