# fastlane-plugin-saucelabs_appdist

[![Gem Version](https://badge.fury.io/rb/fastlane-plugin-saucelabs_appdist.svg)](https://rubygems.org/gems/fastlane-plugin-saucelabs_appdist)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A [Sauce Labs](https://saucelabs.com) fastlane plugin for uploading builds to **Mobile App Distribution**.

For more information about Sauce Labs Mobile App Distribution, see the [product page](https://saucelabs.com/products/mobile-testing/app-betas).

## Installation

```sh
fastlane add_plugin saucelabs_appdist
```

Or add the plugin manually to your project's `Pluginfile`:

```ruby
gem 'fastlane-plugin-saucelabs_appdist'
```

## Usage

```ruby
saucelabs_appdist(
  api_key: "your_api_key",
  ipa: "./path/to/app.ipa",
  comment: "Build #{lane_context[SharedValues::BUILD_NUMBER]}"
)
```

### Uploading to the same app every time

Mobile App Distribution matches an upload to an existing app by its bundle id, within the teams you can write to. When the same bundle id lives on more than one of your teams, the upload cannot tell them apart and is refused with code `136`. Pass `team_id` to say which team owns the app:

```ruby
saucelabs_appdist(
  api_key: "your_api_key",
  ipa: "./path/to/app.ipa",
  team_id: 42,
  landing_page_slug: "my-app-beta"
)
```

Every upload then appends a build to the same app, and `/install/my-app-beta` always serves the latest one. Re-sending the same `landing_page_slug` on every upload is safe — an app may keep claiming its own slug.

`folder_name` takes part in the match as well: an upload finds an existing app only when the folder matches what that app already has, and an upload that sends no folder looks only among apps that have none. So send the same `folder_name` on every upload, or none at all — changing it mid-pipeline routes the next build to a different app.

## Parameters

| Key | Description | Default |
|-----|-------------|---------|
| `api_key` | API Key for Sauce Labs App Distribution | — |
| `ipa` | Path to your IPA file (iOS) | — |
| `apk` | Path to your APK file (Android) | — |
| `symbols_file` | Symbols mapping file | — |
| `upload_url` | API URL for App Distribution | `https://app.testfairy.com` |
| `api_version` | Upload transport. `:v3` arrives in plugin 3.x | `:legacy` |
| `team_id` | Team that owns the app. Required when a bundle id exists on several of your teams | `""` |
| `comment` | Additional release notes | `No comment provided` |
| `notify` | Send email to testers (`on`/`off`/`1`/`0`) | `off` |
| `tags` | Custom tags for builds | `[]` |
| `metadata` | Key-value pairs stored on the build, returned under `metadata` | `{}` |
| `folder_name` | Dashboard folder name | `""` |
| `landing_page_mode` | Landing page visibility (`open`/`closed`) | `open` |
| `landing_page_slug` | Custom URL token for the landing page, served at `/install/<slug>` | `""` |
| `community_token` | Legacy name for `landing_page_slug` | `""` |
| `sync_to_saucelabs` | Also upload the file to Sauce Labs app storage (`on`/`off`) | `off` |
| `platform` | Platform of a generic upload. Ignored for `.ipa`, `.apk` and `.aab` | `""` |
| `timeout` | Request timeout in seconds | — |

### Legacy TestFairy parameters

Mobile App Distribution ignores the parameters below. Private-cloud instances still running legacy TestFairy honor them, so the plugin keeps sending them and warns when you set one.

| Key | Description | Default |
|-----|-------------|---------|
| `testers_groups` | Tester groups to notify. App Distribution notifies every tester on the project | `[]` |
| `app_description` | Landing page description. Set it from the App Distribution dashboard instead | `""` |
| `metrics` | Session metrics recorded by the TestFairy SDK | `[]` |
| `options` | Session options for the TestFairy SDK | `[]` |
| `custom` | Custom options string | `""` |
| `auto_update` | Auto-upgrade users (`on`/`off`) | `off` |
| `upload_to_saucelabs` | Deprecated. Renamed to `sync_to_saucelabs` | `off` |

## Upgrading from 0.3.x

Your Fastfile keeps working. Three things change:

1. **`upload_to_saucelabs` is deprecated.** Mobile App Distribution reads the field as `sync_to_saucelabs`, so the old name uploaded nothing. Rename it; the plugin warns until you do and sends both field names in the meantime.
2. **Parameters App Distribution ignores now warn** instead of returning `status: ok` as though they applied. See the table above.
3. **A failed upload raises the API's own error.** `UI.user_error!` carries the `code` and `message`, and the full envelope lands in `lane_context`.

## Response

The `SAUCELABS_APPDIST_UPLOAD_RESPONSE` shared value contains the full JSON response from the upload API. It is set in `lane_context` and can be accessed in subsequent lanes:

```ruby
lane_context[SharedValues::SAUCELABS_APPDIST_UPLOAD_RESPONSE]
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
  "options": "",
  "platform": "iOS",
  "tags": [],
  "metadata": {},
  "has_testfairy_sdk": false,
  "symbols_download_url": null,
  "attachments": null,
  "landing_page_url": "https://app.testfairy.com/install/xxxxxx",
  "build_specific_landing_page_url": "https://app.testfairy.com/install/0123456789abcdef0123456789abcdef",
  "landing_page_mode": "closed",
  "community_token": "xxxxxx",
  "app_description": ""
}
```

## Errors

A failed upload raises a `FastlaneError` naming the API's own code and message, for example:

```
Sauce Labs App Distribution upload failed with code 136: Invalid team_id.
```

The full error envelope stays in `lane_context` so a lane can decide whether to retry:

```ruby
begin
  saucelabs_appdist(api_key: "...", ipa: "./app.ipa")
rescue FastlaneCore::Interface::FastlaneError
  error = lane_context[SharedValues::SAUCELABS_APPDIST_UPLOAD_ERROR]
  UI.message("code #{error['code']}: #{error['message']}")
  raise
end
```

Codes you are most likely to meet:

| Code | Meaning |
|------|---------|
| `5` | Invalid API key |
| `121` | File type not accepted |
| `124` | `landing_page_slug` is malformed |
| `125` | `landing_page_slug` already belongs to another app |
| `135` | `landing_page_mode` is neither `open` nor `closed` |
| `136` | The bundle id exists on several of your teams — pass `team_id` |
