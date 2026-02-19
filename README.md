# fastlane-plugin-mad

[![Gem Version](https://badge.fury.io/rb/fastlane-plugin-mad.svg)](https://rubygems.org/gems/fastlane-plugin-mad)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A [Sauce Labs](https://saucelabs.com) fastlane plugin for uploading builds to **Mobile App Distribution (MAD)**.

For more information about Sauce Labs Mobile App Distribution, see the [product page](https://saucelabs.com/products/mobile-testing/app-betas).

## Installation

```sh
fastlane add_plugin mad
```

Or add the plugin manually to your project's `Pluginfile`:

```ruby
gem 'fastlane-plugin-mad'
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
| `upload_url` | API URL for MAD | `https://app.testfairy.com` |
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

## Response

The `MAD_UPLOAD_RESPONSE` shared value contains the full JSON response from the upload API. It is set in `lane_context` and can be accessed in subsequent lanes:

```ruby
lane_context[SharedValues::MAD_UPLOAD_RESPONSE]
```

Example response:

```json
{
  "status": "ok",
  "build_id": "1",
  "project_id": "1",
  "app_name": "My Demo App",
  "app_version": "2.0.2 - 2026-02-19 02:51:05",
  "file_size": 2319620,
  "build_url": "https://app.testfairy.com/projects/1/builds/1",
  "download_page_url": "https://app.testfairy.com/join/xxxxxx",
  "app_url": "https://app.testfairy.com/download/.../getapp",
  "invite_testers_url": "https://app.testfairy.com/projects/1/builds/1/invite",
  "icon_url": "https://app.testfairy.com/icons/.../icon.png",
  "options": "video-quality=medium,screenshot-interval=1,session-length=60m,video,logcat,shake,cpu,memory,phone-signal,battery,wifi",
  "platform": "iOS",
  "tags": [],
  "metadata": [],
  "has_testfairy_sdk": true,
  "symbols_download_url": null,
  "attachments": null,
  "landing_page_url": "https://app.testfairy.com/join/xxxxxx",
  "build_specific_landing_page_url": "https://app.testfairy.com/join/xxxxxx?id=1",
  "landing_page_mode": "closed"
}
```
