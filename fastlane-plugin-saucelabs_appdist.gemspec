lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fastlane/plugin/saucelabs_appdist/version'

Gem::Specification.new do |spec|
  spec.name          = 'fastlane-plugin-saucelabs_appdist'
  spec.version       = Fastlane::SaucelabsAppdist::VERSION
  spec.author        = 'Sauce Labs'
  spec.email         = 'mobileappdistribution@saucelabs.com'

  spec.summary       = 'Sauce Labs plugin for uploading builds to Mobile App Distribution'
  spec.description   = 'A Sauce Labs fastlane plugin for uploading iOS and Android builds to Mobile App Distribution.'
  spec.homepage      = 'https://saucelabs.com/products/mobile-testing/app-betas'
  spec.license       = 'MIT'

  spec.files         = Dir["lib/**/*"] + %w(README.md LICENSE)
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.6'

  spec.add_dependency('faraday', '~> 1.0')
  spec.add_dependency('faraday_middleware', '~> 1.0')

  spec.add_development_dependency('bundler')
  spec.add_development_dependency('fastlane', '>= 2.0')
  spec.add_development_dependency('pry')
  spec.add_development_dependency('rake')
  spec.add_development_dependency('rspec')
  spec.add_development_dependency('rubocop', '1.50.2')
end
