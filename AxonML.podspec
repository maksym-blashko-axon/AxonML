Pod::Spec.new do |spec|
  spec.name         = "AxonML"
  spec.version      = "1.0.0"
  # spec.version      = "#VERSION#"
  spec.summary      = "Axon ML kit."
  spec.description  = <<-DESC
  An extended description of AxonML project.
                         DESC
  spec.homepage     = "https://www.axon.dev"
  spec.license      = { :type => 'Copyright', :text => <<-LICENSE
                          Copyright 2018
                          Permission is granted to...
                          LICENSE
                      }
  spec.authors      = { "$(git config user.name)" => "$(git config user.email)" }
  spec.source       = { :http => 'https://github.com/maksym-blashko-axon/AxonML/releases/download/1.0.0/AxonML.xcframework.zip' }
  spec.vendored_frameworks = "AxonML.xcframework"
  spec.source_files = "AxonML/**/*.{swift}"
  spec.platform     = :ios
  spec.swift_version = '5.0'
  spec.ios.deployment_target  = '12.0'

  spec.static_framework = true
  spec.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  spec.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }

  spec.dependency 'SnapKit', '~> 5.6.0'
  spec.dependency 'GoogleMLKit/FaceDetection'
  spec.dependency 'GoogleMLKit/ImageLabeling'
  spec.dependency 'GoogleMLKit/ImageLabelingCustom'
  spec.dependency 'GoogleMLKit/ObjectDetection'
  spec.dependency 'GoogleMLKit/ObjectDetectionCustom'
  spec.dependency 'GoogleMLKit/PoseDetection'
  spec.dependency 'GoogleMLKit/PoseDetectionAccurate'
  spec.dependency 'GoogleMLKit/SegmentationSelfie'
  spec.dependency 'GoogleMLKit/TextRecognition'
  spec.dependency 'GoogleMLKit/TextRecognitionChinese'
  spec.dependency 'GoogleMLKit/TextRecognitionDevanagari'
  spec.dependency 'GoogleMLKit/TextRecognitionJapanese'
  spec.dependency 'GoogleMLKit/TextRecognitionKorean'

end
