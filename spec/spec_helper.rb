$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'fastlane'

# Helper.test? checks for this constant
module SpecHelper
end

Fastlane.load_actions

require 'fastlane/plugin/mad/mad'
