# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "fastimage/version"

Gem::Specification.new do |s|
  s.name = %q{local-fastimage}
  s.version = FastImage::VERSION
  s.authors = ["Stephen Sykes", "Gregor Schmidt (Planio)"]
  s.email = ["sdsykes@gmail.com", "gregor@plan.io", "support@plan.io"]

  s.summary = "Local FastImage - Image info fast"
  s.description = "Local FastImage finds the size or type of an image reading as little bytes as needed."
  s.homepage = "https://github.com/planio-gmbh/local-fastimage"

  s.license = "MIT"

  s.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  s.require_paths = ["lib"]

  s.add_development_dependency "bundler"
  s.add_development_dependency "rake"
  s.add_development_dependency "minitest"
end
