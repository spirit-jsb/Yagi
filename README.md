# Yagi (摩羯)

<p align="center">
  <a href="https://cocoapods.org/pods/Yagi"><img src="https://img.shields.io/cocoapods/v/Yagi.svg?style=for-the-badge"/></a>
  <a href="https://swift.org/package-manager/"><img src="https://img.shields.io/badge/SPM-compatible-orange?style=for-the-badge"></a> 
  <a href="https://cocoapods.org/pods/Yagi"><img src="https://img.shields.io/cocoapods/l/Yagi.svg?style=for-the-badge"/></a>
  <a href="https://cocoapods.org/pods/Yagi"><img src="https://img.shields.io/cocoapods/p/Yagi.svg?style=for-the-badge"/></a>
</p>

`Yagi` 是一个自定义 `AVAssetExportSession` 框架，可以在对导出视频压缩效果不减弱的情况下获得更小的体积。

## 示例代码
```swift
let exportSession = VMAssetExportSession(asset: avasset, preset: .VMAssetExportPreset1080p)
exportSession.outputUrl = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent({file_name}) exportSession.exportAsynchronously(progress: { (progress) in
    // progress handle
}, completion: { (result) in
    // completion result handle
})
```

## 预设压缩参数

预设压缩参数参考了 [Video Encoding Settings
for H.264 Excellence](http://www.lighterra.com/papers/videoencodingh264/#maximumkeyframeinterval) 文章的内容，具体详情如下:

**VMAssetExportPreset1080p**
```swift
video: {
    AVVideoWidthKey: {video_file}.naturalSize.width,
    AVVideoHeightKey: {video_file}.naturalSize.height,
    AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill,
    AVVideoCodecKey: AVVideoCodecH264
    AVVideoColorPropertiesKey: {
        AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
        AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
        AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
    },
    AVVideoCompressionPropertiesKey: {
        AVVideoAverageBitRateKey: 4992000.0,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264High41,
        AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC,
        AVVideoAverageNonDroppableFrameRateKey: 30.0
    }
},

audio: {
    AVFormatIDKey: kAudioFormatMPEG4AAC,
    AVSampleRateKey: 44100.0,
    AVNumberOfChannelsKey: 2,
    AVEncoderBitRateKey: 128000.0
}
```

**VMAssetExportPreset720p**
```swift
video: {
    AVVideoWidthKey: {video_file}.naturalSize.width,
    AVVideoHeightKey: {video_file}.naturalSize.height,
    AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill,
    AVVideoCodecKey: AVVideoCodecH264
    AVVideoColorPropertiesKey: {
        AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
        AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
        AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
    },
    AVVideoCompressionPropertiesKey: {
        AVVideoAverageBitRateKey: 2496000.0,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264High41,
        AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC,
        AVVideoAverageNonDroppableFrameRateKey: 30.0
    }
},

audio: {
    AVFormatIDKey: kAudioFormatMPEG4AAC,
    AVSampleRateKey: 44100.0,
    AVNumberOfChannelsKey: 2,
    AVEncoderBitRateKey: 64000.0
}
```

**VMAssetExportPreset480p**
```swift
video: {
    AVVideoWidthKey: {video_file}.naturalSize.width,
    AVVideoHeightKey: {video_file}.naturalSize.height,
    AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill,
    AVVideoCodecKey: AVVideoCodecH264
    AVVideoColorPropertiesKey: {
        AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
        AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
        AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
    },
    AVVideoCompressionPropertiesKey: {
        AVVideoAverageBitRateKey: 1216000.0,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264High41,
        AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC,
        AVVideoAverageNonDroppableFrameRateKey: 30.0
    }
},

audio: {
    AVFormatIDKey: kAudioFormatMPEG4AAC,
    AVSampleRateKey: 44100.0,
    AVNumberOfChannelsKey: 2,
    AVEncoderBitRateKey: 64000.0
}
```

**VMAssetExportPreset360p**
```swift
video: {
    AVVideoWidthKey: {video_file}.naturalSize.width,
    AVVideoHeightKey: {video_file}.naturalSize.height,
    AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill,
    AVVideoCodecKey: AVVideoCodecH264
    AVVideoColorPropertiesKey: {
        AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
        AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
        AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
    },
    AVVideoCompressionPropertiesKey: {
        AVVideoAverageBitRateKey: 896000.0,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264High41,
        AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC,
        AVVideoAverageNonDroppableFrameRateKey: 30.0
    }
},

audio: {
    AVFormatIDKey: kAudioFormatMPEG4AAC,
    AVSampleRateKey: 44100.0,
    AVNumberOfChannelsKey: 2,
    AVEncoderBitRateKey: 64000.0
}
```

为了防止因为视频实际尺寸小于压缩参数的目标尺寸导致压缩后出现黑边的情况，`AVVideoWidthKey`和 `AVVideoHeightKey` 参数的具体计算过程如下:
```swift
let videoTracks = asset.tracks(withMediaType: .video)
guard let videoTrack = videoTracks.first else {
    return nil
}

let size = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
var videoNaturalSize: CGSize! = CGSize(width: abs(size.width), height: abs(size.height))

if videoNaturalSize.width == 0.0 || videoNaturalSize.height == 0.0 {
    videoNaturalSize = nil
}
else if videoNaturalSize.width * videoNaturalSize.height > preset.width * preset.height {
    let aspectRatio = videoNaturalSize.width / videoNaturalSize.height
    let width: CGFloat = abs(aspectRatio > 1.0 ? preset.width : preset.height)
    let height: CGFloat = abs(width / aspectRatio)

    videoNaturalSize = CGSize(width: width, height: height)
}

return videoNaturalSize
```

## 压缩效果
被压缩视频[源文件](https://drive.google.com/file/d/19-iTIOl5JHq-eXN2dw0va46p5XJFjPs4/view?usp=sharing)

压缩结果:
Name | Resolution | Video Bitrate (Mbps) | Audio Bitrate (kbps) | Audio Sampling Rate (kHz) | Size (MB)  
-|-|-|-|-|-
源文件 | 3840*2160 | 50.2 | 128.0 | 48.0 | 378.7 |
VMAssetExportPreset1080p | 1920*1080 | 5.0 | 128.0 | 44.1 | 38.6 |
VMAssetExportPreset720p | 1280*720 | 2.5 | 64.0 | 44.1 | 19.0 |
VMAssetExportPreset480p | 848*478 | 1.2 | 64.0 | 44.1 | 9.5 |
VMAssetExportPreset360p | 640*360 | 0.9 | 64.0 | 44.1 | 7.2 |
AVAssetExportPreset1920x1080 | 1920*1080 | 14.9 | 128.0 | 48.0 | 114.0 |
AVAssetExportPreset1280x720 | 1280*720 | 10.3 | 128.0 | 48.0 | 79.3 |
AVAssetExportPreset640x480 | 640*360 | 2.6 | 128.0 | 48.0 | 21.8 |

压缩后效果图:

**Source Frame**</br>
![source_frame](https://raw.githubusercontent.com/spirit-jsb/Yagi/master/img/source_frame.png)

**VMAssetExportPreset1080p**</br>
![VMAssetExportPreset1080p_frame.png](https://raw.githubusercontent.com/spirit-jsb/Yagi/master/img/VMAssetExportPreset1080p_frame.png)

**VMAssetExportPreset720p**</br>
![VMAssetExportPreset720p_frame.png](https://raw.githubusercontent.com/spirit-jsb/Yagi/master/img/VMAssetExportPreset720p_frame.png)

**VMAssetExportPreset480p**</br>
![VMAssetExportPreset480p_frame.png](https://raw.githubusercontent.com/spirit-jsb/Yagi/master/img/VMAssetExportPreset480p_frame.png)

**VMAssetExportPreset360p**</br>
![VMAssetExportPreset360p_frame.png](https://raw.githubusercontent.com/spirit-jsb/Yagi/master/img/VMAssetExportPreset360p_frame.png)

**AVAssetExportPreset1920x1080**</br>
![AVAssetExportPreset1920x1080_frame.png](https://raw.githubusercontent.com/spirit-jsb/Yagi/master/img/AVAssetExportPreset1920x1080_frame.png)

**AVAssetExportPreset1280x720**</br>
![AVAssetExportPreset1280x720_frame.png](https://raw.githubusercontent.com/spirit-jsb/Yagi/master/img/AVAssetExportPreset1280x720_frame.png)

**AVAssetExportPreset640x480**</br>
![AVAssetExportPreset640x480_frame.png](https://raw.githubusercontent.com/spirit-jsb/Yagi/master/img/AVAssetExportPreset640x480_frame.png)

## 限制条件
- iOS 10.0+
- Swift 5.0+    

## 安装

### **CocoaPods**
``` ruby
pod 'Yagi', '~> 1.0.0'
```

### **Swift Package Manager**
```
https://github.com/spirit-jsb/Yagi.git
```

## 作者
spirit-jsb, sibo_jian_29903549@163.com

## 许可文件
`Yagi` 可在 `MIT` 许可下使用，更多详情请参阅许可文件。
