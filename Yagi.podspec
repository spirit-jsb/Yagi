Pod::Spec.new do |s|
    
    s.name = 'Yagi'
    s.version = '1.0.1'

    s.summary = 'Yagi 是一个自定义 AVAssetExportSession 框架。'
    s.description = <<-DESC
                    Yagi 是一个自定义 AVAssetExportSession 框架，可以在对导出视频压缩效果不减弱的情况下获得更小的体积
                    DESC

    s.authors = { 'spirit-jsb' => 'sibo_jian_29903549@163.com' }
    s.license = 'MIT'
    
    s.homepage = 'https://github.com/spirit-jsb/Yagi.git'

    s.ios.deployment_target = '10.0'

    s.swift_versions = ['5.0']

    s.frameworks = 'Foundation', 'AVFoundation', 'CoreServices'

    s.source = { :git => 'https://github.com/spirit-jsb/Yagi.git', :tag => s.version }

    s.default_subspecs = 'Core'
    
    s.subspec 'Core' do |sp|
        sp.source_files = ["Sources/Core/**/*.swift", "Sources/Yagi.h"]
    end

end