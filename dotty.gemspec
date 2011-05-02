# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)
require 'dotty/version'

Gem::Specification.new do |s|
  s.name        = 'dotty'
  s.version     = Dotty::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Trym Skaar']
  s.email       = ['trym@tryms.no']
  s.homepage    = 'http://github.com/trym/dotty'
  s.summary     = %q{Dotfile manager using git repositories}
  s.description = %q{Command line tool for easily managing your dotfile git repositories}

  s.rubyforge_project = "dotty"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_dependency 'thor'
  s.add_dependency 'hashie'

  s.add_development_dependency 'rspec', '>= 2.6.0.rc4'
  s.add_development_dependency 'simplecov', '>= 0.4.0'
end
