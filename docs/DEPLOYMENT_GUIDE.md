# Deployment Guide (Android & iOS)

This guide describes how to produce **release builds** for SignSync and prepare App Store / Play Store submissions.

> This repository intentionally does **not** contain any signing secrets. Follow the procedures below to generate and store them securely.

## 1. Versioning

- App version is set in `pubspec.yaml`:

```yaml
version: 1.0.0+1
```

- `1.0.0` = marketing version
- `+1` = build number (Android versionCode / iOS build)

Update `lib/utils/constants.dart` only if you intentionally display a fixed version string in the UI.

## 2. Disable debug logging

SignSync uses `LoggerService` which is configured to output verbose logs only in debug mode. Ensure that new code paths do not use `print()`/`debugPrint()` for production telemetry.

## 3. Android release builds

### 3.1 Release configuration
- `android/app/build.gradle` enables:
  - R8/ProGuard minification (`minifyEnabled true`)
  - resource shrinking (`shrinkResources true`)
  - optional native symbol stripping
- ProGuard rules are in `android/app/proguard-rules.pro`

### 3.2 Generate keystore

```bash
SIGN_SYNC_KEYSTORE_PASSWORD='...' \
SIGN_SYNC_KEY_PASSWORD='...' \
./scripts/release/android_generate_keystore.sh
```

This creates:
- `android/keystore/signsync-release.jks`
- `android/key.properties`

### 3.3 Secure key storage (required)
- Never commit `android/key.properties` or `*.jks`/`*.keystore`.
- Store in:
  - 1Password/Bitwarden, OR
  - Google Cloud Secret Manager/AWS Secrets Manager, OR
  - CI secret store (GitHub Actions secrets, etc.)
- Make a documented backup procedure. Losing the keystore means you cannot update the Android app.

### 3.4 Build signed artifacts

Recommended for Play Store: **AAB**

```bash
./scripts/release/android_build_release.sh
```

Outputs:
- `build/app/outputs/bundle/release/app-release.aab`
- `build/app/outputs/flutter-apk/app-release.apk`

### 3.5 Verify signing
- The build script verifies APK signing if `apksigner` is available.
- For AAB verification, use Play Console upload validation.

## 4. iOS release builds

### 4.1 Certificates and provisioning
Use Apple Developer Program:
- Create App ID (bundle identifier)
- Create distribution certificate
- Create App Store provisioning profile

Recommended workflow:
- Use **Xcode Automatic Signing** for the mainline path
- Use **App Store Connect API + fastlane** for CI (optional)

### 4.2 Export options
A template exists at `ios/ExportOptions.plist`.

### 4.3 Build IPA

```bash
./scripts/release/ios_build_release.sh
```

Output:
- `build/ios/ipa/*.ipa`

### 4.4 dSYM / symbol uploads
For crash reporting in production:
- Keep iOS dSYMs and upload to your crash provider (Sentry/Firebase Crashlytics)
- For Android, consider using `debugSymbolLevel 'SYMBOL_TABLE'` and upload symbols if needed

## 5. App Store Connect checklist

- Create App record (bundle ID must match)
- Add:
  - name, subtitle, description
  - keywords
  - support URL
  - privacy policy URL (required)
  - screenshots for required device sizes
  - app review information
- Set pricing and availability
- Upload build via Xcode or Transporter
- Configure TestFlight (internal + external testers)

## 6. Google Play Console checklist

- Create App
- Set:
  - app details
  - store listing (short + full description)
  - screenshots + feature graphic
  - privacy policy URL (required)
  - data safety form
  - content rating
  - pricing & distribution
- Upload AAB to internal testing
- Promote to closed/open testing
- Submit for production review

## 7. Privacy policy & Terms hosting

This repository includes drafts:
- `docs/legal/PRIVACY_POLICY.md`
- `docs/legal/TERMS_OF_SERVICE.md`

Recommended hosting options:
- Static site (GitHub Pages, Cloudflare Pages, Netlify)
- Your primary marketing domain (e.g., `https://signsync.app/legal/...`)

Update the in-app URLs in `lib/utils/constants.dart` after hosting.

## 8. Beta testing

### iOS (TestFlight)
- Add internal testers (App Store Connect users)
- Add external testers via groups
- Provide:
  - what to test
  - known issues
  - feedback email

### Android (Play Internal Testing)
- Create internal testing track
- Add tester email list or Google Group
- Upload AAB
- Share opt-in link

## 9. Pre-release verification checklist

- Analyzer clean (no warnings)
- Unit tests passing
- Performance validation on representative devices
- Accessibility audit (WCAG target)
- Security review (secrets, encryption, data handling)

See also: `docs/ACCESSIBILITY_AUDIT.md`
