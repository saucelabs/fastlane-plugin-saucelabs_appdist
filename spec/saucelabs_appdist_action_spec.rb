describe Fastlane::Actions::SaucelabsAppdistAction do
  let(:action) { Fastlane::Actions::SaucelabsAppdistAction }

  before do
    @tmp_ipa = File.join(Dir.tmpdir, 'test.ipa')
    File.write(@tmp_ipa, 'dummy ipa content')
  end

  after do
    File.delete(@tmp_ipa) if File.exist?(@tmp_ipa)
  end

  def config(values = {})
    FastlaneCore::Configuration.create(
      action.available_options,
      { api_key: 'abc123', ipa: @tmp_ipa }.merge(values)
    )
  end

  def fields(values = {})
    action.client_options(config(values))
  end

  describe '#run' do
    it 'returns the ipa path in test mode' do
      result = Fastlane::FastFile.new.parse("lane :test do
        saucelabs_appdist(api_key: 'abc123', ipa: '#{@tmp_ipa}')
      end").runner.execute(:test)

      expect(result).to eq(@tmp_ipa)
    end

    it 'returns the apk path in test mode' do
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

    it 'accepts team_id from a lane' do
      result = Fastlane::FastFile.new.parse("lane :test do
        saucelabs_appdist(api_key: 'abc123', ipa: '#{@tmp_ipa}', team_id: 42)
      end").runner.execute(:test)

      expect(result).to eq(@tmp_ipa)
    end
  end

  describe '#client_options' do
    it 'maps every declared option' do
      expect { fields }.not_to raise_error
    end

    it 'refuses an option it has no mapping for, rather than dropping it' do
      unmapped = FastlaneCore::ConfigItem.new(key: :not_mapped_anywhere, optional: true, default_value: 'x')
      params = FastlaneCore::Configuration.create(
        action.available_options + [unmapped],
        { api_key: 'abc123', ipa: @tmp_ipa }
      )

      expect { action.client_options(params) }
        .to raise_error(FastlaneCore::Interface::FastlaneError, /Unknown parameter: not_mapped_anywhere/)
    end

    it 'keeps local-only config off the wire' do
      expect(fields.keys).not_to include(:upload_url, :timeout, :api_version)
    end

    it 'sends team_id' do
      expect(fields(team_id: 42)[:team_id]).to eq('42')
    end

    it 'sends the legacy auto-update field name' do
      expect(fields(auto_update: 'on')['auto-update']).to eq('on')
    end

    it 'joins array params into comma-separated fields' do
      expect(fields(tags: %w(qa nightly))[:tags]).to eq('qa,nightly')
      expect(fields(testers_groups: %w(QA Developers))[:testers_groups]).to eq('QA,Developers')
    end
  end

  describe 'sync_to_saucelabs' do
    it 'sends both field names so one lane works on either server' do
      result = fields(sync_to_saucelabs: 'on')

      expect(result[:sync_to_saucelabs]).to eq('on')
      expect(result[:upload_to_saucelabs]).to eq('on')
    end

    it 'maps the deprecated name onto the field App Distribution reads' do
      expect(FastlaneCore::UI).to receive(:important).with(/`upload_to_saucelabs` is deprecated/)

      result = fields(upload_to_saucelabs: 'on')

      expect(result[:sync_to_saucelabs]).to eq('on')
      expect(result[:upload_to_saucelabs]).to eq('on')
    end

    it 'defaults to off without a deprecation warning' do
      expect(FastlaneCore::UI).not_to receive(:important)

      expect(fields[:sync_to_saucelabs]).to eq('off')
    end

    it 'refuses contradicting values' do
      expect { fields(sync_to_saucelabs: 'on', upload_to_saucelabs: 'off') }
        .to raise_error(FastlaneCore::Interface::FastlaneError, /contradicts/)
    end

    it 'never lets the deprecated name quietly override an explicit off' do
      expect { fields(sync_to_saucelabs: 'off', upload_to_saucelabs: 'on') }
        .to raise_error(FastlaneCore::Interface::FastlaneError, /contradicts/)
    end
  end

  describe 'landing_page_slug' do
    it 'sends both the new and the legacy field name' do
      result = fields(landing_page_slug: 'my-app-beta')

      expect(result[:landing_page_slug]).to eq('my-app-beta')
      expect(result[:community_token]).to eq('my-app-beta')
    end

    it 'accepts the legacy community_token as an alias' do
      result = fields(community_token: 'my-app-beta')

      expect(result[:landing_page_slug]).to eq('my-app-beta')
      expect(result[:community_token]).to eq('my-app-beta')
    end

    it 'sends an empty slug when neither is set, which the server reads as "leave it alone"' do
      expect(fields[:landing_page_slug]).to eq('')
    end

    it 'refuses contradicting values' do
      expect { fields(landing_page_slug: 'new-slug', community_token: 'old-slug') }
        .to raise_error(FastlaneCore::Interface::FastlaneError, /contradicts/)
    end
  end

  describe 'metadata' do
    it 'expands each pair into a metadata_ field' do
      result = fields(metadata: { branch: 'main', ci_build: 1234 })

      expect(result['metadata_branch']).to eq('main')
      expect(result['metadata_ci_build']).to eq('1234')
    end

    it 'sends no metadata field when the hash is empty' do
      expect(fields.keys.grep(/^metadata_/)).to eq([])
    end

    it 'refuses a blank key' do
      expect { fields(metadata: { '  ' => 'x' }) }
        .to raise_error(FastlaneCore::Interface::FastlaneError, /Metadata keys cannot be empty/)
    end
  end

  describe '#warn_ignored_params' do
    it 'warns for each param App Distribution ignores' do
      action::IGNORED_BY_APPDIST.each_key do |key|
        value = case key
                when :metrics then [:cpu]
                when :options then [:shake]
                when :testers_groups then %w(QA)
                when :auto_update then 'on'
                else 'something'
                end

        expect(FastlaneCore::UI).to receive(:important).with(/ignores `#{key}`/)
        action.warn_ignored_params(config(key => value))
      end
    end

    it 'stays quiet when every ignored param is left at its default' do
      expect(FastlaneCore::UI).not_to receive(:important)

      action.warn_ignored_params(config)
    end

    it 'warns that platform is ignored for a binary upload' do
      expect(FastlaneCore::UI).to receive(:important).with(/ignores `platform`/)

      action.warn_ignored_params(config(platform: 'windowsphone'))
    end

    it 'stays quiet about platform when no binary is uploaded' do
      tmp_zip = File.join(Dir.tmpdir, 'test.zip')
      File.write(tmp_zip, 'dummy zip content')

      expect(FastlaneCore::UI).not_to receive(:important)
      action.warn_ignored_params(config(ipa: tmp_zip, platform: 'windowsphone'))

      File.delete(tmp_zip) if File.exist?(tmp_zip)
    end
  end

  describe '#upload_error_message' do
    it 'surfaces the API code and message' do
      response = double(status: 400, body: { 'status' => 'fail', 'code' => 136, 'message' => 'Invalid team_id.' })

      expect(action.upload_error_message(response))
        .to eq('Sauce Labs App Distribution upload failed with code 136: Invalid team_id.')
    end

    it 'keeps the whole envelope in lane_context for retry logic' do
      body = { 'status' => 'fail', 'code' => 125, 'message' => 'community_token is already in use.' }
      action.upload_error_message(double(status: 400, body: body))

      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SAUCELABS_APPDIST_UPLOAD_ERROR]).to eq(body)
    end

    it 'falls back to the HTTP status when the body carries no code' do
      expect(action.upload_error_message(double(status: 502, body: '<html>bad gateway</html>')))
        .to match(/HTTP 502/)
    end
  end

  describe '#available_options' do
    it 'has the correct default upload_url' do
      upload_url_option = action.available_options.find { |o| o.key == :upload_url }
      expect(upload_url_option.default_value).to eq('https://app.testfairy.com')
    end

    it 'rejects a notify value neither server acts on' do
      expect { config(notify: 'true') }
        .to raise_error(FastlaneCore::Interface::FastlaneError, /notify flag can only be/)
    end

    it 'accepts the notify values both servers act on' do
      %w(on off 1 0).each { |value| expect { config(notify: value) }.not_to raise_error }
    end

    it 'rejects a non-numeric team_id' do
      expect { config(team_id: 'nike') }
        .to raise_error(FastlaneCore::Interface::FastlaneError, /team_id must be a number/)
    end

    it 'points api_version :v3 at plugin 3.x' do
      expect { config(api_version: :v3) }
        .to raise_error(FastlaneCore::Interface::FastlaneError, /needs plugin 3\.x/)
    end

    it 'rejects an unknown api_version' do
      expect { config(api_version: :v9) }
        .to raise_error(FastlaneCore::Interface::FastlaneError, /supports :legacy only/)
    end
  end

  describe '#is_supported?' do
    it 'supports iOS' do
      expect(action.is_supported?(:ios)).to be(true)
    end

    it 'supports Android' do
      expect(action.is_supported?(:android)).to be(true)
    end

    it 'does not support Mac' do
      expect(action.is_supported?(:mac)).to be(false)
    end
  end
end
