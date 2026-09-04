module Fastlane
  module Actions
    module SharedValues
      SAUCELABS_APPDIST_UPLOAD_RESPONSE = :SAUCELABS_APPDIST_UPLOAD_RESPONSE
      SAUCELABS_APPDIST_UPLOAD_ERROR = :SAUCELABS_APPDIST_UPLOAD_ERROR
    end

    class SaucelabsAppdistAction < Action
      # Config that stays on this side of the wire.
      LOCAL_ONLY_PARAMS = %i[upload_url timeout api_version].freeze

      # Params whose lane name is also the upload field name.
      PASSTHROUGH_PARAMS = %i[
        api_key ipa apk symbols_file comment notify custom platform
        folder_name landing_page_mode app_description
      ].freeze

      # Params resolved as a pair or expanded into several fields.
      RECONCILED_PARAMS = %i[
        community_token landing_page_slug upload_to_saucelabs sync_to_saucelabs metadata
      ].freeze

      # Mobile App Distribution ignores these. Legacy TestFairy servers still
      # read them, so they stay on the wire and only warn.
      IGNORED_BY_APPDIST = {
        testers_groups: 'Mobile App Distribution notifies every tester on the project; per-group notify is not available yet.',
        app_description: 'Set the landing page description from the dashboard.',
        metrics: 'Session metrics came from the TestFairy SDK, which Mobile App Distribution does not ship.',
        options: 'Session options came from the TestFairy SDK, which Mobile App Distribution does not ship.',
        custom: 'No equivalent.',
        auto_update: 'No equivalent.'
      }.freeze

      BINARY_EXTENSIONS = %w(.ipa .apk .aab).freeze

      def self.upload_build(upload_url, ipa, options, timeout)
        require 'faraday'
        require 'faraday_middleware'

        UI.success("Uploading to #{upload_url}...")

        connection = Faraday.new(url: upload_url) do |builder|
          builder.request(:multipart)
          builder.request(:url_encoded)
          builder.request(:retry, max: 3, interval: 5)
          builder.response(:json, content_type: /\bjson$/)
          builder.use(FaradayMiddleware::FollowRedirects)
          builder.adapter(:net_http)
        end

        options[:file] = Faraday::UploadIO.new(ipa, 'application/octet-stream') if ipa && File.exist?(ipa)

        symbols_file = options.delete(:symbols_file)
        if symbols_file
          options[:symbols_file] = Faraday::UploadIO.new(symbols_file, 'application/octet-stream')
        end

        begin
          connection.post do |req|
            req.options.timeout = timeout
            req.url("/api/upload/")
            req.body = options
          end
        rescue Faraday::TimeoutError
          UI.crash!("Uploading build to Sauce Labs App Distribution timed out ⏳")
        end
      end

      def self.run(params)
        UI.success('Starting with ipa upload to Sauce Labs App Distribution...')

        path = params[:ipa] || params[:apk]
        UI.user_error!("No ipa or apk were given") unless path

        # One snapshot, taken before `params.values` back-fills defaults into
        # the same hash it reads from.
        given = provided_keys(params)
        warn_ignored_params(params, given)
        client_options = self.client_options(params, given)

        return path if Helper.test?

        response = self.upload_build(params[:upload_url], path, client_options, params[:timeout])
        UI.user_error!(upload_error_message(response)) unless parse_response(response)

        UI.success("Build successfully uploaded to Sauce Labs App Distribution.")
        UI.success("Response:\n#{JSON.pretty_generate(Actions.lane_context[SharedValues::SAUCELABS_APPDIST_UPLOAD_RESPONSE])}")
      end

      # Build the upload fields. Every declared option is either mapped here or
      # named in LOCAL_ONLY_PARAMS — an option added without a mapping fails
      # loud instead of vanishing.
      def self.client_options(params, given = provided_keys(params))
        options = {}

        params.values.each_key do |key|
          value = params[key]

          case key
          when *LOCAL_ONLY_PARAMS, *RECONCILED_PARAMS
            next
          when *PASSTHROUGH_PARAMS
            options[key] = value
          when :team_id
            options[key] = value.to_s
          when :testers_groups, :tags
            options[key] = Array(value).join(',')
          when :metrics
            options[key] = metrics_to_client(value).join(',')
          when :options
            options[key] = options_to_client(value).join(',')
          when :auto_update
            options['auto-update'] = value
          else
            UI.user_error!("Unknown parameter: #{key}")
          end
        end

        slug = landing_page_slug(params, given)
        options[:community_token] = slug
        options[:landing_page_slug] = slug

        sync = sync_to_saucelabs(params, given)
        options[:upload_to_saucelabs] = sync
        options[:sync_to_saucelabs] = sync

        options.merge(metadata_fields(params[:metadata]))
      end

      # `upload_to_saucelabs` is the legacy field name; Mobile App Distribution
      # reads `sync_to_saucelabs`. Both go out so one lane works on either.
      def self.sync_to_saucelabs(params, given = provided_keys(params))
        legacy = provided?(params, :upload_to_saucelabs, given) ? params[:upload_to_saucelabs] : nil
        current = provided?(params, :sync_to_saucelabs, given) ? params[:sync_to_saucelabs] : nil

        if legacy && current && legacy != current
          UI.user_error!("`upload_to_saucelabs: '#{legacy}'` contradicts `sync_to_saucelabs: '#{current}'`. Keep `sync_to_saucelabs`.")
        end

        UI.important("`upload_to_saucelabs` is deprecated — rename it to `sync_to_saucelabs`.") if legacy

        current || legacy || params[:sync_to_saucelabs]
      end

      # `community_token` is the legacy name for `landing_page_slug`.
      def self.landing_page_slug(params, given = provided_keys(params))
        legacy = provided?(params, :community_token, given) ? params[:community_token] : nil
        current = provided?(params, :landing_page_slug, given) ? params[:landing_page_slug] : nil

        if legacy && current && legacy != current
          UI.user_error!("`community_token: '#{legacy}'` contradicts `landing_page_slug: '#{current}'`. Pass one of them.")
        end

        current || legacy || ''
      end

      # Mobile App Distribution folds every `metadata_<key>` field into the
      # build's metadata, so one hash entry becomes one field.
      def self.metadata_fields(metadata)
        (metadata || {}).each_with_object({}) do |(key, value), fields|
          name = key.to_s.strip
          UI.user_error!("Metadata keys cannot be empty") if name.empty?

          fields["metadata_#{name}"] = value.to_s
        end
      end

      def self.warn_ignored_params(params, given = provided_keys(params))
        IGNORED_BY_APPDIST.each do |key, alternative|
          next unless provided?(params, key, given)

          UI.important("Sauce Labs Mobile App Distribution ignores `#{key}`. #{alternative} Legacy TestFairy servers still honor it.")
        end

        return unless provided?(params, :platform, given) && binary_upload?(params)

        UI.important('Sauce Labs Mobile App Distribution ignores `platform` for .ipa, .apk and .aab uploads — it reads the platform from the binary. The param applies to generic uploads only.')
      end

      # Keys the lane actually passed. Read this BEFORE `params.values`, which
      # back-fills defaults into the very hash it reports as caller-supplied.
      def self.provided_keys(params)
        return params._values.keys if params.respond_to?(:_values)

        # Older fastlane: fall back to "differs from its declared default",
        # which cannot tell an explicit default from an absent value.
        available_options.reject { |option| params[option.key] == option.default_value }.map(&:key)
      end

      # True when the lane passed the param and gave it a real value.
      def self.provided?(params, key, given = provided_keys(params))
        given.include?(key) && ![nil, '', [], {}].include?(params[key])
      end

      def self.binary_upload?(params)
        path = params[:ipa] || params[:apk]
        return false unless path

        BINARY_EXTENSIONS.include?(File.extname(path.to_s).downcase)
      end

      def self.metrics_to_client(metrics)
        Array(metrics).map do |metric|
          case metric.to_sym
          when :cpu, :memory, :network, :gps, :battery, :mic, :wifi
            metric.to_s
          when :phone_signal
            'phone-signal'
          else
            UI.user_error!("Unknown metric: #{metric}")
          end
        end
      end

      def self.options_to_client(options)
        Array(options).map do |option|
          case option.to_sym
          when :shake, :anonymous
            option.to_s
          when :video_only_wifi
            'video-only-wifi'
          else
            UI.user_error!("Unknown option: #{option}")
          end
        end
      end

      # Surface the API's own code and message so a lane can act on them, and
      # keep the whole envelope in lane_context for retry logic.
      def self.upload_error_message(response)
        body = response.body
        Actions.lane_context[SharedValues::SAUCELABS_APPDIST_UPLOAD_ERROR] = body

        if body.is_a?(Hash) && body['code']
          "Sauce Labs App Distribution upload failed with code #{body['code']}: #{body['message'] || '(no message)'}"
        else
          "Sauce Labs App Distribution upload failed with HTTP #{response.status}: #{body.inspect}"
        end
      end

      def self.parse_response(response)
        return false unless response.body.is_a?(Hash) && response.body['status'] == 'ok'

        Actions.lane_context[SharedValues::SAUCELABS_APPDIST_UPLOAD_RESPONSE] = response.body

        true
      end
      private_class_method :parse_response

      def self.description
        'Upload a new build to Sauce Labs App Distribution'
      end

      def self.details
        'A Sauce Labs fastlane plugin for uploading iOS and Android builds to Mobile App Distribution (MAD).'
      end

      def self.available_options
        [
          # required
          FastlaneCore::ConfigItem.new(key: :api_key,
                                       env_name: "FL_SAUCELABS_APPDIST_API_KEY",
                                       description: "API Key for Sauce Labs App Distribution",
                                       sensitive: true,
                                       verify_block: proc do |value|
                                         UI.user_error!("No API key for Sauce Labs App Distribution given, pass using `api_key: 'key'`") unless value.to_s.length > 0
                                       end),
          FastlaneCore::ConfigItem.new(key: :ipa,
                                       env_name: 'SAUCELABS_APPDIST_IPA_PATH',
                                       description: 'Path to your IPA file for iOS',
                                       default_value: Actions.lane_context[SharedValues::IPA_OUTPUT_PATH],
                                       default_value_dynamic: true,
                                       optional: true,
                                       conflicting_options: [:apk],
                                       verify_block: proc do |value|
                                         UI.user_error!("Couldn't find ipa file at path '#{value}'") unless File.exist?(value)
                                       end),
          FastlaneCore::ConfigItem.new(key: :apk,
                                       env_name: 'SAUCELABS_APPDIST_APK_PATH',
                                       description: 'Path to your APK file for Android',
                                       default_value: Actions.lane_context[SharedValues::GRADLE_APK_OUTPUT_PATH],
                                       default_value_dynamic: true,
                                       optional: true,
                                       conflicting_options: [:ipa],
                                       verify_block: proc do |value|
                                         UI.user_error!("Couldn't find apk file at path '#{value}'") unless File.exist?(value)
                                       end),
          # optional
          FastlaneCore::ConfigItem.new(key: :symbols_file,
                                       optional: true,
                                       env_name: "FL_SAUCELABS_APPDIST_SYMBOLS_FILE",
                                       description: "Symbols mapping file",
                                       default_value: Actions.lane_context[SharedValues::DSYM_OUTPUT_PATH],
                                       default_value_dynamic: true,
                                       verify_block: proc do |value|
                                         UI.user_error!("Couldn't find dSYM file at path '#{value}'") unless File.exist?(value)
                                       end),
          FastlaneCore::ConfigItem.new(key: :upload_url,
                                       env_name: "FL_SAUCELABS_APPDIST_UPLOAD_URL",
                                       description: "API URL for Sauce Labs App Distribution",
                                       default_value: "https://app.testfairy.com",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :api_version,
                                       optional: true,
                                       type: Symbol,
                                       env_name: "FL_SAUCELABS_APPDIST_API_VERSION",
                                       description: "Upload transport. This release supports :legacy (the /api/upload endpoint) only; :v3 arrives in plugin 3.x",
                                       default_value: :legacy,
                                       verify_block: proc do |value|
                                         if value.to_sym == :v3
                                           UI.user_error!("`api_version: :v3` needs plugin 3.x — this is #{Fastlane::SaucelabsAppdist::VERSION}, which uploads over the legacy /api/upload endpoint")
                                         end
                                         UI.user_error!("Unknown api_version `#{value}`. This release supports :legacy only") unless value.to_sym == :legacy
                                       end),
          FastlaneCore::ConfigItem.new(key: :team_id,
                                       optional: true,
                                       env_name: "FL_SAUCELABS_APPDIST_TEAM_ID",
                                       skip_type_validation: true,
                                       description: "Team that owns the app. Pass it when the same bundle id exists on more than one of your teams, otherwise the upload is refused with code 136",
                                       default_value: '',
                                       verify_block: proc do |value|
                                         UI.user_error!("The team_id must be a number") unless value.to_s.empty? || value.to_s.match?(/\A\d+\z/)
                                       end),
          FastlaneCore::ConfigItem.new(key: :testers_groups,
                                       optional: true,
                                       type: Array,
                                       short_option: '-g',
                                       env_name: "FL_SAUCELABS_APPDIST_TESTERS_GROUPS",
                                       description: "Array of tester groups to be notified. Legacy TestFairy only — Mobile App Distribution notifies every tester on the project",
                                       default_value: []),
          FastlaneCore::ConfigItem.new(key: :metrics,
                                       optional: true,
                                       type: Array,
                                       env_name: "FL_SAUCELABS_APPDIST_METRICS",
                                       description: "Array of metrics to record (cpu,memory,network,phone_signal,gps,battery,mic,wifi). Legacy TestFairy SDK only",
                                       default_value: []),
          FastlaneCore::ConfigItem.new(key: :comment,
                                       optional: true,
                                       env_name: "FL_SAUCELABS_APPDIST_COMMENT",
                                       description: "Additional release notes for this upload. This text will be added to email notifications",
                                       default_value: 'No comment provided'),
          FastlaneCore::ConfigItem.new(key: :auto_update,
                                       optional: true,
                                       env_name: "FL_SAUCELABS_APPDIST_AUTO_UPDATE",
                                       description: "Allows an easy upgrade of all users to the current version. To enable set to 'on'. Legacy TestFairy only",
                                       default_value: 'off'),
          FastlaneCore::ConfigItem.new(key: :notify,
                                       optional: true,
                                       env_name: "FL_SAUCELABS_APPDIST_NOTIFY",
                                       description: "Send email to testers. Can be 'on' or 'off'",
                                       default_value: 'off',
                                       verify_block: proc do |value|
                                         UI.user_error!("The notify flag can only be on, off, 1 or 0 — any other value silently notifies nobody") unless %w(on off 1 0).include?(value.to_s)
                                       end),
          FastlaneCore::ConfigItem.new(key: :options,
                                       optional: true,
                                       type: Array,
                                       env_name: "FL_SAUCELABS_APPDIST_OPTIONS",
                                       description: "Array of options (shake,video_only_wifi,anonymous). Legacy TestFairy SDK only",
                                       default_value: []),
          FastlaneCore::ConfigItem.new(key: :custom,
                                       optional: true,
                                       env_name: "FL_SAUCELABS_APPDIST_CUSTOM",
                                       description: "Array of custom options. Legacy TestFairy only — contact support for more information",
                                       default_value: ''),
          FastlaneCore::ConfigItem.new(key: :timeout,
                                       env_name: "FL_SAUCELABS_APPDIST_TIMEOUT",
                                       description: "Request timeout in seconds",
                                       type: Integer,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :tags,
                                       optional: true,
                                       env_name: "FL_SAUCELABS_APPDIST_TAGS",
                                       description: "Custom tags that can be used to organize your builds",
                                       type: Array,
                                       default_value: []),
          FastlaneCore::ConfigItem.new(key: :metadata,
                                       optional: true,
                                       type: Hash,
                                       env_name: "FL_SAUCELABS_APPDIST_METADATA",
                                       description: "Arbitrary key-value pairs to store on the build. Each pair is sent as a metadata_<key> field and comes back under `metadata` in the response",
                                       default_value: {}),
          FastlaneCore::ConfigItem.new(key: :folder_name,
                                       optional: true,
                                       env_name: "FL_SAUCELABS_APPDIST_FOLDER_NAME",
                                       description: "Name of the dashboard folder that contains this app",
                                       default_value: ''),
          FastlaneCore::ConfigItem.new(key: :landing_page_mode,
                                       optional: true,
                                       env_name: "FL_SAUCELABS_APPDIST_LANDING_PAGE_MODE",
                                       description: "Visibility of build landing after upload. Can be 'open' or 'closed'",
                                       default_value: 'open',
                                       verify_block: proc do |value|
                                         UI.user_error!("The landing page mode can only be open or closed") unless %w(open closed).include?(value)
                                       end),
          FastlaneCore::ConfigItem.new(key: :sync_to_saucelabs,
                                       optional: true,
                                       env_name: "FL_SAUCELABS_APPDIST_SYNC_TO_SAUCELABS",
                                       description: "Also upload the file to Sauce Labs app storage. It can be 'on' or 'off'",
                                       default_value: 'off',
                                       verify_block: proc do |value|
                                         UI.user_error!("The sync to Sauce Labs can only be on or off") unless %w(on off).include?(value)
                                       end),
          FastlaneCore::ConfigItem.new(key: :upload_to_saucelabs,
                                       optional: true,
                                       deprecated: "Renamed to `sync_to_saucelabs`, which is the field Mobile App Distribution reads",
                                       env_name: "FL_SAUCELABS_APPDIST_UPLOAD_TO_SAUCELABS",
                                       description: "Upload file directly to Sauce Labs. It can be 'on' or 'off'",
                                       default_value: 'off',
                                       verify_block: proc do |value|
                                         UI.user_error!("The upload to Sauce Labs can only be on or off") unless %w(on off).include?(value)
                                       end),
          FastlaneCore::ConfigItem.new(key: :platform,
                                       optional: true,
                                       env_name: "FL_SAUCELABS_APPDIST_PLATFORM",
                                       description: "Platform of a generic upload. Ignored for .ipa, .apk and .aab, whose platform comes from the binary",
                                       default_value: ''),
          FastlaneCore::ConfigItem.new(key: :landing_page_slug,
                                       optional: true,
                                       env_name: "FL_SAUCELABS_APPDIST_LANDING_PAGE_SLUG",
                                       description: "Custom URL token for the landing page, served at /install/<slug>. 6-63 chars: letters, digits, dot, hyphen or underscore",
                                       default_value: ''),
          FastlaneCore::ConfigItem.new(key: :community_token,
                                       optional: true,
                                       env_name: "FL_SAUCELABS_APPDIST_COMMUNITY_TOKEN",
                                       description: "Legacy name for `landing_page_slug`",
                                       default_value: ''),
          FastlaneCore::ConfigItem.new(key: :app_description,
                                       optional: true,
                                       env_name: "FL_SAUCELABS_APPDIST_APP_DESCRIPTION",
                                       description: "Description text for the landing page. Legacy TestFairy only — Mobile App Distribution never writes it",
                                       default_value: '')
        ]
      end

      def self.example_code
        [
          'saucelabs_appdist(
            api_key: "...",
            ipa: "./ipa_file.ipa",
            comment: "Build #{lane_context[SharedValues::BUILD_NUMBER]}",
          )',
          'saucelabs_appdist(
            api_key: "...",
            apk: "../build/app/outputs/apk/qa/release/app-qa-release.apk",
            comment: "Build #{lane_context[SharedValues::BUILD_NUMBER]}",
           )',
          '# Same bundle id on several teams: name the team so every upload
          # appends to the same app instead of forking a new one.
          saucelabs_appdist(
            api_key: "...",
            ipa: "./ipa_file.ipa",
            team_id: 42,
            landing_page_slug: "my-app-beta",
            metadata: { branch: "main", ci_build: "1234" },
          )'
        ]
      end

      def self.category
        :beta
      end

      def self.output
        [
          ['SAUCELABS_APPDIST_UPLOAD_RESPONSE', 'Full response from the upload API'],
          ['SAUCELABS_APPDIST_UPLOAD_ERROR', 'Full error envelope (status, code, message) from a failed upload']
        ]
      end

      def self.authors
        ["Sauce Labs"]
      end

      def self.is_supported?(platform)
        [:ios, :android].include?(platform)
      end
    end
  end
end
