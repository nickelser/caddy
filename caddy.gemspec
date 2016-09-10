# -*- encoding: utf-8 -*-
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "caddy/version"

Gem::Specification.new do |s|
  s.name          = "caddy"
  s.version       = Caddy::VERSION
  s.authors       = ["Nick Elser"]
  s.email         = ["nick.elser@gmail.com"]
  s.description   = %q(Caddy gives you a auto-updating global cache to speed up requests.)
  s.summary       = %q(Caddy gives you a auto-updating global cache to speed up requests.)
  s.homepage      = "http://github.com/nickelser/caddy"
  s.licenses      = ["MIT"]

  s.files         = `git ls-files`.split($/)
  s.executables   = s.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]

  s.required_ruby_version = "~> 2.0"

  s.add_dependency "concurrent-ruby", "~> 1.0"

  s.add_development_dependency "rake", "~> 10.5"
  s.add_development_dependency "minitest", "~> 5.0"
  s.add_development_dependency "codeclimate-test-reporter", "~> 0.4.7"
end
