# -*- encoding: utf-8 -*-

lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'naplug/version'
require 'naplug/about'

Gem::Specification.new do |s|
  s.name                      = Naplug::ME.to_s
  s.version                   = Naplug::VERSION
  s.platform                  = Gem::Platform::RUBY
  s.authors                   = 'Gerardo López-Fernádez'
  s.email                     = 'gerir@evernote.com'
  s.homepage                  = 'https://github.com/gerirgaudi/naplug'
  s.summary                   = 'A Ruby library for Nagios plugins'
  s.description               = 'A Ruby library for Nagios plugins '
  s.license                   = 'Apache License, Version 2.0'
  s.required_rubygems_version = '>= 1.3.5'

  s.files        = Dir['lib/**/*.rb'] + Dir['examples/*'] + %w(LICENSE README.md)
  s.require_path = 'lib'
end
