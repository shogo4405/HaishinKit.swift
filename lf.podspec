Pod::Spec.new do |s|

  s.name         = "lf"
  s.version      = "0.0.1"
  s.summary      = "RTMP Publish Library for iOS"

  s.description  = <<-DESC
                   DESC

  s.homepage     = "https://github.com/shogo4405/lf.swift"
  s.license      = "MIT (example)"
  s.author             = { "shogo4405" => "shogo4405@gmail.com" }
  s.authors            = { "shogo4405" => "shogo4405@gmail.com" }
  s.social_media_url   = "http://twitter.com/shogo4405"
  s.platform     = :ios
  s.source       = { :git => "https://github.com/shogo4405/lf.swift.git", :tag => "0.0.1" }

  s.source_files  = "lf", "lf/**/*.swift"

end
