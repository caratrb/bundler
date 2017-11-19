# coding: utf-8
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
require 'carat/version'

Gem::Specification.new do |s|
  s.name        = 'carat'
  s.version     = Carat::VERSION
  s.licenses    = ['MIT']
  s.authors     = ["Justin Searls", "Aaron Patterson", "Eileen Uchitelle", "Sam Phippen", "André Arko", "Terence Lee", "Carl Lerche", "Yehuda Katz"]
  s.email       = ["searls@gmail.com"]
  s.homepage    = "https://github.com/caratrb/carat"
  s.summary     = %q{One way to manage your application's dependencies}
  s.description = %q{Carat manages an application's dependencies through its entire life, across many machines, systematically and repeatably}

  s.required_ruby_version     = '>= 2.2.2'
  s.required_rubygems_version = '>= 1.3.6'

  s.add_development_dependency 'mustache',  '0.99.6'
  s.add_development_dependency 'rdiscount', '~> 1.6'
  s.add_development_dependency 'ronn',      '~> 0.7.3'
  s.add_development_dependency 'rspec',     '~> 3.0'
  s.add_development_dependency 'rake'

  s.files       = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  # we don't check in man pages, but we need to ship them because
  # we use them to generate the long-form help for each command.
  s.files      += Dir.glob('lib/carat/man/**/*')

  s.executables   = %w(carat karat)
  s.require_paths = ["lib"]
end
