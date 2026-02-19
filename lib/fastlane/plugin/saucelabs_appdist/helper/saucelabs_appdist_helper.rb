require 'fastlane_core/ui/ui'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class SaucelabsAppdistHelper
      def self.show_message
        UI.message("Hello from the saucelabs_appdist plugin helper!")
      end
    end
  end
end
