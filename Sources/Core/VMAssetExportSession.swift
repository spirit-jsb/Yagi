//
//  VMAssetExportSession.swift
//  Yagi
//
//  Created by max on 2020/9/12.
//  Copyright © 2020 max. All rights reserved.
//

#if canImport(Foundation) && canImport(AVFoundation) && canImport(CoreServices)

import Foundation
import AVFoundation
import CoreServices

public class VMAssetExportSession: NSObject {
  
  /// VMAssetExportSession 导出会话预设
  public enum Preset {
    case VMAssetExportPreset360p
    case VMAssetExportPreset480p
    case VMAssetExportPreset720p
    case VMAssetExportPreset720pHQ
    case VMAssetExportPreset1080p
    case VMAssetExportPreset1080pHQ
  }
  
  /// VMAssetExportSession 导出会话状态
  public enum Status: Int {
    case unknown = 0
    case exporting = 1
    case completed = 2
    case failed = 3
    case cancelled = 4
  }
  
  /// VMAssetExportSession 导出会话错误
  public enum Error: Swift.Error {
    case setExportSessionFailure
    case verifyVideoSettingsFailure
    case setWriterFailure
    case writerFailure(Swift.Error?)
    case setReaderFailure
    case readerFailure(Swift.Error?)
    case cancelled
    case unknown
  }
  
  public typealias ProgressHandler = (Float) -> Void
  public typealias CompletionHandler = (Swift.Result<Bool, Error>) -> Void
  
  /// 用于初始化 VMAssetExportSession 的 AVAsset 实例
  public let asset: AVAsset
  
  /// 文件格式 UTIs (Read Only)
  public private(set) var outputFileType: AVFileType? = nil
  
  /// 输出文件名拓展 (Read Only)
  public var outputFilenameExtension: String? {
    guard let inUTI = self.outputFileType?.rawValue else {
      return nil
    }
    guard let filenameExtension = UTTypeCopyPreferredTagWithClass(inUTI as CFString, kUTTagClassFilenameExtension)?.takeUnretainedValue() else {
      return nil
    }
    return String(filenameExtension)
  }
  
  /// 指示导出会话输出 URL
  public var outputUrl: URL?
  
  /// 是否以更适合在网络上回放的方式优化输出, 默认值为 true
  public var shouldOptimizeForNetworkUse: Bool = true
  
  /// 指示导出会话状态 (Read Only)
  public var status: VMAssetExportSession.Status? {
    if let _writer = self._writer {
      return VMAssetExportSession.Status(rawValue: _writer.status.rawValue)
    }
    return .unknown
  }
  
  /// 指示导出会话进度 (Read Only)
  public private(set) var progress: Float = 0.0
  
  /// 视频输出配置 (Read Only)
  public private(set) var videoSettings = [String: Any]()
  /// 音频输出配置 (Read Only)
  public private(set) var audioSettings = [String: Any]()
  
  private let _preset: Preset
  private let _timeRange: CMTimeRange
  private let _globalQueue: DispatchQueue
  private let _videoInputQueue: DispatchQueue
  private let _audioInputQueue: DispatchQueue
  
  private var _writer: AVAssetWriter?
  private var _videoInput: AVAssetWriterInput?
  private var _audioInput: AVAssetWriterInput?
  
  private var _reader: AVAssetReader?
  private var _videoOutput: AVAssetReaderVideoCompositionOutput?
  private var _audioOutput: AVAssetReaderAudioMixOutput?
  
  private var _bufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
  
  private var _duration: Float64 = 0.0
  
  private var _retryDelay: TimeInterval = 0.5
  
  private var _progressCallback: ProgressHandler?
  private var _completionCallback: CompletionHandler?
  
  /// 初始化 VMAssetExportSession 实例
  /// - Parameters:
  ///   - asset: 需要导出的 AVAsset 实例
  ///   - preset: 导出预设模版
  public init(asset: AVAsset, preset: Preset) {
    self.asset = asset
    self._preset = preset
    
    self._timeRange = CMTimeRangeMake(start: .zero, duration: .positiveInfinity)
    self._globalQueue = DispatchQueue(label: "com.max.jian.Yagi.export.session", qos: .userInteractive, attributes: [.concurrent], autoreleaseFrequency: .workItem, target: nil)
    self._videoInputQueue = DispatchQueue(label: "com.max.jian.Yagi.export.session.video", qos: .default, autoreleaseFrequency: .workItem, target: self._globalQueue)
    self._audioInputQueue = DispatchQueue(label: "com.max.jian.Yagi.export.session.audio", qos: .default, autoreleaseFrequency: .workItem, target: self._globalQueue)
    
    if let pathExtension = (asset as? AVURLAsset)?.url.pathExtension {
      if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension as CFString, nil)?.takeRetainedValue() {
        self.outputFileType = AVFileType(String(uti))
      }
    }
    
    guard let videoTrack = asset.tracks(withMediaType: .video).first else {
      return
    }
    
    // 校验 video size
    var videoNaturalSize: CGSize = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
    if videoNaturalSize == .zero {
      videoNaturalSize = CGSize(width: preset.width, height: preset.height)
    }
    
    var videoActualSize = CGSize(width: abs(videoNaturalSize.width), height: abs(videoNaturalSize.height))
    if videoActualSize.width * videoActualSize.height > preset.width * preset.height {
      let aspectRatio = videoActualSize.width / videoActualSize.height
      let width: CGFloat = abs(aspectRatio > 1.0 ? preset.width : preset.height)
      let height: CGFloat = abs(width / aspectRatio)
      
      videoActualSize = CGSize(width: width, height: height)
    }
    
    // 校验 video bit rate
    var videoEstimatedBitRate = videoTrack.estimatedDataRate
    if videoEstimatedBitRate == .zero {
      videoEstimatedBitRate = preset.videoBitRate
    }
    
    let videoActualBitRate = min(preset.videoBitRate, videoEstimatedBitRate)
        
    // video settings & audio settings
    self.videoSettings[AVVideoWidthKey] = NSNumber(value: Double(videoActualSize.width))
    self.videoSettings[AVVideoHeightKey] = NSNumber(value: Double(videoActualSize.height))
    self.videoSettings[AVVideoScalingModeKey] = AVVideoScalingModeResizeAspectFill
    self.videoSettings[AVVideoCompressionPropertiesKey] = [
      AVVideoAverageBitRateKey: NSNumber(value: videoActualBitRate),
      AVVideoMaxKeyFrameIntervalDurationKey: NSNumber(value: 2.0),
      AVVideoAllowFrameReorderingKey: NSNumber(value: false),
      AVVideoProfileLevelKey: AVVideoProfileLevelH264High41
    ]
    if #available(iOS 11.0, *) {
      self.videoSettings[AVVideoCodecKey] = AVVideoCodecType.h264
    }
    else {
      self.videoSettings[AVVideoCodecKey] = AVVideoCodecH264
    }
    
    self.audioSettings[AVFormatIDKey] = kAudioFormatMPEG4AAC
    self.audioSettings[AVSampleRateKey] = NSNumber(value: 44100.0)
    self.audioSettings[AVNumberOfChannelsKey] = NSNumber(value: 2)
    self.audioSettings[AVEncoderBitRateKey] = NSNumber(value: preset.audioBitRate)
  }
  
  deinit {
    self._writer = nil
    self._videoInput = nil
    self._audioInput = nil
    
    self._reader = nil
    self._videoOutput = nil
    self._audioOutput = nil
  }
}

extension VMAssetExportSession {
  
  public func updateVideoSetting(_ videoSettings: [String: Any]) {
    self.videoSettings.merge(videoSettings, uniquingKeysWith: { $1 })
  }
  
  public func updateAudioSetting(_ audioSettings: [String: Any]) {
    self.audioSettings.merge(audioSettings, uniquingKeysWith: { $1 })
  }
  
  /// 异步开始导出会话
  public func exportAsynchronously(progress: ProgressHandler? = nil, completion: CompletionHandler? = nil) {
    self._progressCallback = progress
    self._completionCallback = completion
    
    // 抛出未设置 outputUrl & outputFileType 的错误
    guard let outputUrl = self.outputUrl, let outputFileType = self.outputFileType else {
      DispatchQueue.main.async {
        self._completionCallback?(.failure(.setExportSessionFailure))
      }
      return
    }
    
    // 清除 outputUrl 路径对应的文件
    self.cleanSandboxFile(outputUrl: outputUrl)
    
    // 初始化 AVAssetWriter
    do {
      self._writer = try AVAssetWriter(outputURL: outputUrl, fileType: outputFileType)
      self._writer?.shouldOptimizeForNetworkUse = self.shouldOptimizeForNetworkUse
    }
    catch {
      DispatchQueue.main.async {
        self._completionCallback?(.failure(.writerFailure(error)))
      }
      return
    }
    
    // 初始化 AVAssetReader
    do {
      self._reader = try AVAssetReader(asset: self.asset)
      self._reader!.timeRange = self._timeRange
    }
    catch {
      DispatchQueue.main.async {
        self._completionCallback?(.failure(.readerFailure(error)))
      }
      return
    }
    
    // 设置导出文件的时长
    self._duration = self._timeRange.duration.isValid && !self._timeRange.duration.isPositiveInfinity ? CMTimeGetSeconds(self._timeRange.duration) : CMTimeGetSeconds(self.asset.duration)
    
    // 设置 video & audio input & output
    self.setVideoInputOutput(asset: self.asset, reader: self._reader!, writer: self._writer!, videoSettings: self.videoSettings)
    self.setAudioInputOutput(asset: self.asset, reader: self._reader!, writer: self._writer!, audioSettings: self.audioSettings)
    
    // 导出
    self._writer!.startWriting()
    self._reader!.startReading()
    
    self._writer!.startSession(atSourceTime: self._timeRange.start)
    
    let videoSemaphore = DispatchSemaphore(value: 0)
    let audioSemaphore = DispatchSemaphore(value: 0)
    
    let videoTracks = self.asset.tracks(withMediaType: .video)
    if let videoInput = self._videoInput, let videoOutput = self._videoOutput, videoTracks.count > 0 {
      videoInput.requestMediaDataWhenReady(on: self._videoInputQueue) {
        if !self.encodeSamples(readerOutput: videoOutput, writerInput: videoInput) {
          videoSemaphore.signal()
        }
      }
    }
    else {
      videoSemaphore.signal()
    }
    
    if let audioInput = self._audioInput, let audioOutput = self._audioOutput {
      audioInput.requestMediaDataWhenReady(on: self._audioInputQueue) {
        if !self.encodeSamples(readerOutput: audioOutput, writerInput: audioInput) {
          audioSemaphore.signal()
        }
      }
    }
    else {
      audioSemaphore.signal()
    }
    
    self._globalQueue.async {
      videoSemaphore.wait()
      audioSemaphore.wait()
      
      DispatchQueue.main.async {
        self.finished(reader: self._reader!, writer: self._writer!, outputUrl: outputUrl)
      }
    }
  }
}

extension VMAssetExportSession {
  
  // 设置 video input & output
  private func setVideoInputOutput(asset: AVAsset, reader: AVAssetReader, writer: AVAssetWriter, videoSettings: [String: Any]) {
    let videoTracks = asset.tracks(withMediaType: AVMediaType.video)
    guard videoTracks.count > 0 else {
      return
    }
    
    // video output
    self._videoOutput = AVAssetReaderVideoCompositionOutput(videoTracks: videoTracks, videoSettings: nil)
    self._videoOutput!.alwaysCopiesSampleData = false
    self._videoOutput!.videoComposition = self.generateVideoComposition(asset: asset)
    
    if reader.canAdd(self._videoOutput!) {
      reader.add(self._videoOutput!)
    }
    
    // video input
    self._videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
    self._videoInput!.expectsMediaDataInRealTime = false
    
    if writer.canAdd(self._videoInput!) {
      writer.add(self._videoInput!)
    }
    
    // pixel buffer adaptor
    let pixelBufferAttributes: [String : Any] = [
      String(kCVPixelBufferPixelFormatTypeKey): NSNumber(value: Int(kCVPixelFormatType_32RGBA)),
      String(kCVPixelBufferWidthKey): videoSettings[AVVideoWidthKey] as! NSNumber,
      String(kCVPixelBufferHeightKey): videoSettings[AVVideoHeightKey] as! NSNumber,
      String(kCVPixelBufferIOSurfacePropertiesKey): [
        "IOSurfaceOpenGLESTextureCompatibility": NSNumber(value: true),
        "IOSurfaceOpenGLESFBOCompatibility": NSNumber(value: true)
      ]
    ]
    
    self._bufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: self._videoInput!, sourcePixelBufferAttributes: pixelBufferAttributes)
  }
  
  // 设置 audio input & output
  private func setAudioInputOutput(asset: AVAsset, reader: AVAssetReader, writer: AVAssetWriter, audioSettings: [String: Any]) {
    let audioTracks = asset.tracks(withMediaType: .audio)
    guard audioTracks.count > 0 else {
      return
    }
    
    // audio output
    self._audioOutput = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: nil)
    self._audioOutput!.alwaysCopiesSampleData = false
    
    if reader.canAdd(self._audioOutput!) {
      reader.add(self._audioOutput!)
    }
    
    // audio input
    self._audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
    self._audioInput!.expectsMediaDataInRealTime = false
    
    if writer.canAdd(self._audioInput!) {
      writer.add(self._audioInput!)
    }
  }
}

extension VMAssetExportSession {
  
  /// VMAssetExportSession reset export session
  private func resetExportSession() {
    self._writer = nil
    self._videoInput = nil
    self._audioInput = nil
    
    self._reader = nil
    self._videoOutput = nil
    self._audioOutput = nil
    
    self._bufferAdaptor = nil
  }
  
  /// VMAssetExportSession clean sandbox file
  private func cleanSandboxFile(outputUrl: URL?) {
    if let outputUrl = outputUrl, FileManager.default.fileExists(atPath: outputUrl.path) {
      try? FileManager.default.removeItem(at: outputUrl)
    }
  }
  
  // encode samples
  private func encodeSamples(readerOutput: AVAssetReaderOutput, writerInput: AVAssetWriterInput) -> Bool {
    while writerInput.isReadyForMoreMediaData {
      guard let sampleBuffer = readerOutput.copyNextSampleBuffer() else {
        writerInput.markAsFinished()
        return false
      }
      
      var isSuccess: Bool = false
      if readerOutput.mediaType == .video {
        // determine progress
        let currentSamplePresentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer) - self._timeRange.start
        let progress = self._duration == 0.0 ? 1.0 : self._duration != 0.0 ? Float(CMTimeGetSeconds(currentSamplePresentationTime) / self._duration) : 0.0
        self._progressCallback?(progress)
        
        self.progress = progress
        
        // prepare progress frames
        if let pixelBufferAdaptor = self._bufferAdaptor, let pixelBufferPool = pixelBufferAdaptor.pixelBufferPool {
          var pixelBufferOut: CVPixelBuffer? = nil
          
          let result = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &pixelBufferOut)
          
          if result == kCVReturnSuccess, let pixelBuffer = pixelBufferOut {
            isSuccess = pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: currentSamplePresentationTime)
          }
        }
      }
      
      if !isSuccess {
        isSuccess = writerInput.append(sampleBuffer)
      }
      
      return isSuccess
    }
    
    return true
  }
  
  /// VMAssetExportSession generate a new instance of AVMutableVideoComposition
  private func generateVideoComposition(asset: AVAsset) -> AVMutableVideoComposition {
    return self.fixVideoTransform(asset: asset)
  }
  
  /// VMAssetExportSession fix video transform
  private func fixVideoTransform(asset: AVAsset) -> AVMutableVideoComposition {
    let videoComposition = AVMutableVideoComposition(propertiesOf: asset)
    
    guard let videoTrack = asset.tracks(withMediaType: .video).first else {
      return videoComposition
    }
    
    // 设置 frame duration
    var videoFrameRate: Int32 = Int32(videoTrack.nominalFrameRate)
    if videoFrameRate == 0 { videoFrameRate = 30 }
    videoComposition.frameDuration = CMTimeMake(value: 1, timescale: videoFrameRate)
    
    let videoInstruction = AVMutableVideoCompositionInstruction()
    videoInstruction.timeRange = CMTimeRangeMake(start: .zero, duration: asset.duration)
    
    let videoLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
    
    var videoNaturalSize = videoTrack.naturalSize
    videoNaturalSize = CGSize(width: abs(videoNaturalSize.width), height: abs(videoNaturalSize.height))
    
    // 获取视频角度
    func videoAngle() -> Int {
      var angle: Int = 0
      
      let transform = videoTrack.preferredTransform
      switch (transform.a, transform.b, transform.c, transform.d) {
      case (0.0, 1.0, -1.0, 0.0):     // Portrait
        angle = 90
      case (0.0, -1.0, 1.0, 0.0):     // Portrait Upside Down
        angle = 270
      case (1.0, 0.0, 0.0, 1.0):      // Landscape Right
        angle = 0
      case (-1.0, 0.0, 0.0, -1.0):    // Landscape Left
        angle = 180
      default:
        break
      }
      
      return angle
    }
    
    let angle = videoAngle()
    switch angle {
    case 90:
      let fixedTransform = CGAffineTransform(translationX: videoNaturalSize.height, y: 0.0).rotated(by: .pi / 2)
      videoLayerInstruction.setTransform(fixedTransform, at: .zero)
      
      videoComposition.renderSize = CGSize(width: videoNaturalSize.height, height: videoNaturalSize.width)
    case 180:
      let fixedTransform = CGAffineTransform(translationX: videoNaturalSize.width, y: videoNaturalSize.height).rotated(by: .pi)
      videoLayerInstruction.setTransform(fixedTransform, at: .zero)
      
      videoComposition.renderSize = CGSize(width: videoNaturalSize.width, height: videoNaturalSize.height)
    case 270:
      let fixedTransform = CGAffineTransform(translationX: 0.0, y: videoNaturalSize.width).rotated(by: (.pi / 2.0) * 3.0)
      videoLayerInstruction.setTransform(fixedTransform, at: .zero)
      
      videoComposition.renderSize = CGSize(width: videoNaturalSize.height, height: videoNaturalSize.width)
    default:
      videoComposition.renderSize = CGSize(width: videoNaturalSize.width, height: videoNaturalSize.height)
    }
    
    videoInstruction.layerInstructions = [videoLayerInstruction]
    videoComposition.instructions = [videoInstruction]
    
    return videoComposition
  }
  
  /// VMAssetExportSession export retry method
  ///
  /// When VMAssetExportSession encoder is unavailable temporarily, AVAssetWriter would trigger AVError. EncoderTemporarilyUnavailable error, at this time VMAssetExportSession will trigger this method.
  private func retryExport() {
    self.resetExportSession()
    
    DispatchQueue.main.asyncAfter(deadline: .now() + self._retryDelay) {
      self.exportAsynchronously(progress: self._progressCallback, completion: self._completionCallback)
      self._retryDelay *= 2.0
    }
  }
  
  /// VMAssetExportSession finished method
  /// - Parameters:
  ///   - reader: AVAssetReader provides services for obtaining media data from an asset.
  ///   - writer: AVAssetWriter provides services for writing media data to a new file.
  ///   - outputUrl: Indicates the URL of the export session's output.
  private func finished(reader: AVAssetReader, writer: AVAssetWriter, outputUrl: URL) {
    switch (writer.status, reader.status) {
    case (_, .cancelled), (.cancelled, _):
      self.completed(reader: reader, writer: writer, outputUrl: outputUrl)
    case (.failed, _):
      writer.cancelWriting()
      self.completed(reader: reader, writer: writer, outputUrl: outputUrl)
    case (_, .failed):
      reader.cancelReading()
      self.completed(reader: reader, writer: writer, outputUrl: outputUrl)
    default:
      writer.finishWriting(completionHandler: {
        self.completed(reader: reader, writer: writer, outputUrl: outputUrl)
      })
    }
  }
  
  /// VMAssetExportSession completed method
  /// - Parameters:
  ///   - reader: AVAssetReader provides services for obtaining media data from an asset.
  ///   - writer: AVAssetWriter provides services for writing media data to a new file.
  ///   - outputUrl: Indicates the URL of the export session's output.
  private func completed(reader: AVAssetReader, writer: AVAssetWriter, outputUrl: URL) {
    switch (writer.status, reader.status) {
    case (.cancelled, _), (_, .cancelled):
      self.cleanSandboxFile(outputUrl: outputUrl)
      
      self._completionCallback?(.failure(.cancelled))
    case (.failed, _):
      self.cleanSandboxFile(outputUrl: outputUrl)
      
      if (writer.error as? AVError)?.code == .encoderTemporarilyUnavailable {
        self.retryExport()
      }
      else {
        self._completionCallback?(.failure(writer.error != nil ? .writerFailure(writer.error) : .unknown))
      }
    case (_, .failed):
      self.cleanSandboxFile(outputUrl: outputUrl)
      
      self._completionCallback?(.failure(reader.error != nil ? .readerFailure(reader.error) : .unknown))
    default:
      self._completionCallback?(.success(true))
    }
  }
}

extension VMAssetExportSession.Preset {
  
  var width: CGFloat {
    switch self {
    case .VMAssetExportPreset360p:
      return 640.0
    case .VMAssetExportPreset480p:
      return 848.0
    case .VMAssetExportPreset720p, .VMAssetExportPreset720pHQ:
      return 1280.0
    case .VMAssetExportPreset1080p, .VMAssetExportPreset1080pHQ:
      return 1920.0
    }
  }
  
  var height: CGFloat {
    switch self {
    case .VMAssetExportPreset360p:
      return 360.0
    case .VMAssetExportPreset480p:
      return 480.0
    case .VMAssetExportPreset720p, .VMAssetExportPreset720pHQ:
      return 720.0
    case .VMAssetExportPreset1080p, .VMAssetExportPreset1080pHQ:
      return 1080.0
    }
  }
  
  var videoBitRate: Float {
    switch self {
    case .VMAssetExportPreset360p:
      return 896.0 * 1000.0
    case .VMAssetExportPreset480p:
      return 1216.0 * 1000.0
    case .VMAssetExportPreset720p:
      return 2496.0 * 1000.0
    case .VMAssetExportPreset720pHQ:
      return 3072.0 * 1000.0
    case .VMAssetExportPreset1080p:
      return 4992.0 * 1000.0
    case .VMAssetExportPreset1080pHQ:
      return 7552.0 * 1000.0
    }
  }
  
  var audioBitRate: Float {
    switch self {
    case .VMAssetExportPreset360p, .VMAssetExportPreset480p:
      return 64.0 * 1000.0
    case .VMAssetExportPreset720p, .VMAssetExportPreset720pHQ, .VMAssetExportPreset1080p, .VMAssetExportPreset1080pHQ:
      return 128.0 * 1000.0
    }
  }
}

#endif
