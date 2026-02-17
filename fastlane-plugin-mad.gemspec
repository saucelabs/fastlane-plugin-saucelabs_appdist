lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fastlane/plugin/mad/version'

Gem::Specification.new do |spec|
  spec.name          = 'fastlane-plugin-mad'
  spec.version       = Fastlane::Mad::VERSION
  spec.author        = 'Simon Sarrafi'
  spec.email         = 'simon@example.com'

  spec.summary       = 'Upload builds to MAD (TestFairy-compatible)'
  spec.homepage      = 'https://github.com/example/fastlane-plugin-mad'
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
