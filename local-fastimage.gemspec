# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "fastimage/version"

Gem::Specification.new do |s|
  s.name = %q{local-fastimage}
  s.version = FastImage::VERSION
  s.summary = %q{FastImage - Image info fast}
  s.description = %q{FastImage finds the size or type of an image given its uri by fetching as little as needed.}

  s.authors = ["Stephen Sykes"]
  s.email = %q{sdsykes@gmail.com}
  s.homepage = %q{http://github.com/sdsykes/fastimage}

  s.license = "MIT"

  s.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  s.require_paths = ["lib"]

  s.add_development_dependency "bundler", "~> 1.12"
  s.add_development_dependency "rake", "~> 10.0"
  s.add_development_dependency "minitest", "~> 5.0"
end
