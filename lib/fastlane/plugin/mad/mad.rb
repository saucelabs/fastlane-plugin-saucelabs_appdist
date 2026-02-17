require 'fastlane/plugin/mad/version'

module Fastlane
  module Mad
    def self.all_classes
      Dir[File.expand_path('**/{actions,helper}/*.rb', File.dirname(__FILE__))]
    end
  end
end

Fastlane::Mad.all_classes.each do |current|
  require current
end
