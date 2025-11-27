# Craft Fastlane Templates

Pre-configured Fastlane setups for iOS and Android deployment.

## iOS Setup

1. Copy the `ios/` directory to your project's `ios/fastlane/` directory
2. Install Fastlane: `gem install fastlane`
3. Configure your app details in `Appfile`
4. Set up code signing with Match (recommended):
   ```bash
   fastlane match init
   fastlane match development
   fastlane match appstore
   ```

### Available Lanes

```bash
# Building
fastlane ios build_debug    # Build debug version
fastlane ios build_release  # Build release version

# Testing
fastlane ios test           # Run unit tests
fastlane ios ui_test        # Run UI tests

# Beta Distribution
fastlane ios beta           # Deploy to TestFlight
fastlane ios promote_beta   # Promote to external testers

# App Store
fastlane ios release        # Submit to App Store
fastlane ios submit_review  # Submit for review

# Utilities
fastlane ios screenshots    # Capture App Store screenshots
fastlane ios update_metadata # Update App Store metadata
```

### Required Environment Variables

```bash
# Apple Developer Account
APPLE_ID=developer@example.com
TEAM_ID=XXXXXXXXXX
APP_IDENTIFIER=com.example.craftapp

# App Store Connect API (recommended for CI)
APP_STORE_CONNECT_KEY_ID=XXXXXXXXXX
APP_STORE_CONNECT_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
APP_STORE_CONNECT_KEY_CONTENT=<base64 encoded .p8 file>

# Match (code signing)
MATCH_GIT_URL=git@github.com:your-org/certificates.git
MATCH_PASSWORD=<encryption password>
```

## Android Setup

1. Copy the `android/` directory to your project's `android/fastlane/` directory
2. Install Fastlane: `gem install fastlane`
3. Configure your app details in `Appfile`
4. Create a Google Play Service Account and download the JSON key

### Available Lanes

```bash
# Building
fastlane android build_debug   # Build debug APK
fastlane android build_release # Build release APK
fastlane android build_bundle  # Build App Bundle (AAB)

# Testing
fastlane android test              # Run unit tests
fastlane android instrumented_test # Run instrumented tests
fastlane android lint              # Run lint checks

# Beta Distribution
fastlane android internal  # Deploy to Internal Testing
fastlane android alpha     # Deploy to Alpha
fastlane android beta      # Deploy to Beta

# Production
fastlane android release          # Deploy to Production
fastlane android staged_rollout   # Deploy with staged rollout
fastlane android complete_rollout # Complete rollout to 100%

# Utilities
fastlane android screenshots      # Capture Play Store screenshots
fastlane android update_metadata  # Update Play Store metadata
```

### Required Environment Variables

```bash
# Google Play
PACKAGE_NAME=com.example.craftapp
SUPPLY_JSON_KEY=./fastlane/play-store-key.json
# Or for CI:
SUPPLY_JSON_KEY_DATA=<JSON key content>

# Signing (set in gradle.properties or as env vars)
KEYSTORE_FILE=./keystore.jks
KEYSTORE_PASSWORD=<password>
KEY_ALIAS=<alias>
KEY_PASSWORD=<password>
```

## CI/CD Integration

### GitHub Actions

```yaml
- name: Setup Ruby
  uses: ruby/setup-ruby@v1
  with:
    ruby-version: '3.2'
    bundler-cache: true

- name: Install Fastlane
  run: gem install fastlane

- name: Deploy to TestFlight
  run: fastlane ios ci_beta
  env:
    APP_STORE_CONNECT_KEY_ID: ${{ secrets.APP_STORE_KEY_ID }}
    APP_STORE_CONNECT_ISSUER_ID: ${{ secrets.APP_STORE_ISSUER_ID }}
    APP_STORE_CONNECT_KEY_CONTENT: ${{ secrets.APP_STORE_KEY_CONTENT }}
```

### GitLab CI

```yaml
deploy:ios:
  stage: deploy
  script:
    - gem install fastlane
    - cd ios && fastlane ci_beta
  variables:
    APP_STORE_CONNECT_KEY_ID: $APP_STORE_KEY_ID
    APP_STORE_CONNECT_ISSUER_ID: $APP_STORE_ISSUER_ID
    APP_STORE_CONNECT_KEY_CONTENT: $APP_STORE_KEY_CONTENT
```

## Creating Google Play Service Account

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project or select existing one
3. Enable Google Play Android Developer API
4. Create a Service Account with Editor role
5. Download JSON key file
6. Link service account in [Google Play Console](https://play.google.com/console) -> Settings -> API access

## Match Code Signing (iOS)

Match stores certificates and profiles in a Git repository, ensuring all team members and CI use the same signing credentials.

```bash
# Initialize Match
fastlane match init

# Generate certificates
fastlane match development  # Development certificates
fastlane match appstore     # App Store certificates
fastlane match adhoc        # Ad-hoc distribution

# Refresh certificates
fastlane match nuke development  # Remove all development certs
fastlane match development --force  # Regenerate
```

## Troubleshooting

### iOS: "No profiles for 'com.example.app' were found"
Run `fastlane match development` and `fastlane match appstore` to generate profiles.

### Android: "Error getting version codes"
Ensure your app has at least one upload to any track on Google Play Console.

### CI builds failing with signing errors
- iOS: Verify `APP_STORE_CONNECT_KEY_CONTENT` is base64 encoded
- Android: Verify `SUPPLY_JSON_KEY_DATA` contains the full JSON content
