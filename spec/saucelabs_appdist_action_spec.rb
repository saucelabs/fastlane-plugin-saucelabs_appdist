describe Fastlane::Actions::SaucelabsAppdistAction do
  describe '#run' do
    before do
      # Create a dummy IPA file for testing
      @tmp_ipa = File.join(Dir.tmpdir, 'test.ipa')
      File.write(@tmp_ipa, 'dummy ipa content')
    end

    after do
      File.delete(@tmp_ipa) if File.exist?(@tmp_ipa)
    end

    it 'returns the ipa path in test mode' do
      result = Fastlane::FastFile.new.parse("lane :test do
        saucelabs_appdist(api_key: 'abc123', ipa: '#{@tmp_ipa}')
      end").runner.execute(:test)

      expect(result).to eq(@tmp_ipa)
    end

    it 'returns the apk path in test mode' do
      # Create a dummy APK file
      tmp_apk = File.join(Dir.tmpdir, 'test.apk')
      File.write(tmp_apk, 'dummy apk content')

      result = Fastlane::FastFile.new.parse("lane :test do
        saucelabs_appdist(api_key: 'abc123', apk: '#{tmp_apk}')
      end").runner.execute(:test)

      expect(result).to eq(tmp_apk)

      File.delete(tmp_apk) if File.exist?(tmp_apk)
    end

    it 'raises an error if no ipa or apk is provided' do
      expect do
        Fastlane::FastFile.new.parse("lane :test do
          saucelabs_appdist(api_key: 'abc123')
        end").runner.execute(:test)
      end.to raise_error(FastlaneCore::Interface::FastlaneError, "No ipa or apk were given")
    end
  end

  describe '#available_options' do
    it 'has the expected number of options' do
      expect(Fastlane::Actions::SaucelabsAppdistAction.available_options.length).to eq(20)
    end

    it 'has the correct default upload_url' do
      upload_url_option = Fastlane::Actions::SaucelabsAppdistAction.available_options.find { |o| o.key == :upload_url }
      expect(upload_url_option.default_value).to eq('https://app.testfairy.com')
    end
  end

  describe '#is_supported?' do
    it 'supports iOS' do
      expect(Fastlane::Actions::SaucelabsAppdistAction.is_supported?(:ios)).to be(true)
    end

    it 'supports Android' do
      expect(Fastlane::Actions::SaucelabsAppdistAction.is_supported?(:android)).to be(true)
    end

    it 'does not support Mac' do
      expect(Fastlane::Actions::SaucelabsAppdistAction.is_supported?(:mac)).to be(false)
    end
  end
end
