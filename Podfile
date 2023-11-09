platform :ios, '15.0' # set IPHONEOS_DEPLOYMENT_TARGET for the pods project

post_install do |installer|
    installer.pods_project.build_configurations.each do |config|
      config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
    end
  
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      end
    end
end

target 'AxonML' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!
  
  # Pods for AxonML
  pod 'SnapKit', '~> 5.6.0'
  pod 'GoogleMLKit/FaceDetection'
  pod 'GoogleMLKit/ImageLabeling'
  pod 'GoogleMLKit/ImageLabelingCustom'
  pod 'GoogleMLKit/ObjectDetection'
  pod 'GoogleMLKit/ObjectDetectionCustom'
  pod 'GoogleMLKit/PoseDetection'
  pod 'GoogleMLKit/PoseDetectionAccurate'
  pod 'GoogleMLKit/SegmentationSelfie'
  pod 'GoogleMLKit/TextRecognition'
  pod 'GoogleMLKit/TextRecognitionChinese'
  pod 'GoogleMLKit/TextRecognitionDevanagari'
  pod 'GoogleMLKit/TextRecognitionJapanese'
  pod 'GoogleMLKit/TextRecognitionKorean'
end
