require 'fastlane/plugin/saucelabs_appdist/version'

module Fastlane
  module SaucelabsAppdist
    def self.all_classes
      Dir[File.expand_path('**/{actions,helper}/*.rb', File.dirname(__FILE__))]
    end
  end
end

Fastlane::SaucelabsAppdist.all_classes.each do |current|
  require current
end
