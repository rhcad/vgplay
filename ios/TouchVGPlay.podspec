Pod::Spec.new do |s|
  s.name        = "TouchVGPlay"
  s.version     = "0.0.3"
  s.summary     = "A vector shape playing framework on TouchVG."

  s.platform    = :ios, "6.0"
  s.source      = { :git => "http://172.19.34.127/git/TouchVGPlay.git", :branch => "master" }
  s.source_files  = "core/*.{h,cpp}", "ios/include/*.h", "ios/src/*.mm"
  s.public_header_files = "ios/include/*.h"

  s.requires_arc = true
  s.xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'gnu++11',
    'CLANG_CXX_LIBRARY' => 'libc++',
    "HEADER_SEARCH_PATHS" => '$(PODS_ROOT)/Headers/TouchVGCore $(PODS_ROOT)/Headers/TouchVG'
  }
  s.dependency "TouchVG"
end
