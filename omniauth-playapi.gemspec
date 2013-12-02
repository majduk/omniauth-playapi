# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)
require 'omniauth/playapi/version'

Gem::Specification.new do |gem|
  gem.authors       = ["Michal Ajduk"]
  gem.email         = ["michal.ajduk@play.pl"]
  gem.description   = 'PlayAPI OAuth2 Strategy for OmniAuth library. Details: http://oauth.play.pl'
  gem.summary       = 'PlayAPI OAuth2 Strategy for OmniAuth'
  gem.homepage      = "http://oauth.play.pl"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "omniauth-playapi"
  gem.require_paths = ["lib"]
  gem.version       = Omniauth::Playapi::VERSION
  gem.add_runtime_dependency 'omniauth-oauth2', '~> 1.1'
end
