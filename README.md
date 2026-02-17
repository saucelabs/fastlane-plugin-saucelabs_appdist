# fastlane-plugin-mad

Upload builds to MAD (TestFairy-compatible upload endpoint).

## Installation

Add the plugin to your project's `Pluginfile`:

```ruby
gem 'fastlane-plugin-mad', path: '/path/to/fastlane-plugin-mad'
```

## Usage

```ruby
mad(
  api_key: "your_api_key",
  ipa: "./path/to/app.ipa",
  comment: "Build #{lane_context[SharedValues::BUILD_NUMBER]}"
)
```

## Parameters

| Key | Description | Default |
|-----|-------------|---------|
| `api_key` | API Key for MAD | — |
| `ipa` | Path to your IPA file (iOS) | — |
| `apk` | Path to your APK file (Android) | — |
| `symbols_file` | Symbols mapping file | — |
| `upload_url` | API URL for MAD | `http://localhost.testfairy.net` |
| `testers_groups` | Array of tester groups | `[]` |
| `metrics` | Array of metrics to record | `[]` |
| `comment` | Additional release notes | `No comment provided` |
| `auto_update` | Auto-upgrade users (`on`/`off`) | `off` |
| `notify` | Send email to testers (`on`/`off`) | `off` |
| `options` | Array of options | `[]` |
| `custom` | Custom options string | `""` |
| `timeout` | Request timeout in seconds | — |
| `tags` | Custom tags for builds | `[]` |
| `folder_name` | Dashboard folder name | `""` |
| `landing_page_mode` | Landing page visibility (`open`/`closed`) | `open` |
| `upload_to_saucelabs` | Upload to Sauce Labs (`on`/`off`) | `off` |
| `platform` | Platform override | `""` |
