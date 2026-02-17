require 'fastlane_core/ui/ui'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class MadHelper
      def self.show_message
        UI.message("Hello from the mad plugin helper!")
      end
    end
  end
end
