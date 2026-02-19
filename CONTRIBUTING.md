# Contributing to fastlane-plugin-saucelabs_appdist

## Development Setup

1. Clone the repo and install dependencies:
   ```sh
   git clone git@gitlab.tools.saucelabs.net:saucelabs/mad/fastlane-plugin-saucelabs_appdist.git
   cd fastlane-plugin-saucelabs_appdist
   bundle install
   ```

2. Run tests:
   ```sh
   bundle exec rspec
   ```

## Publishing a New Version

1. Update the version number in `lib/fastlane/plugin/saucelabs_appdist/version.rb`.

2. Build the gem:
   ```sh
   gem build fastlane-plugin-saucelabs_appdist.gemspec
   ```

3. Push to RubyGems:
   ```sh
   gem push fastlane-plugin-saucelabs_appdist-<version>.gem
   ```

4. Clients can then update to the new version:
   ```sh
   bundle update fastlane-plugin-saucelabs_appdist
   ```
