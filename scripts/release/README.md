# Release Scripts

These scripts automate common release build steps.

## Android

1. Generate a keystore (creates `android/keystore/signsync-release.jks` and `android/key.properties`):

```bash
SIGN_SYNC_KEYSTORE_PASSWORD='...' \
SIGN_SYNC_KEY_PASSWORD='...' \
./scripts/release/android_generate_keystore.sh
```

2. Build signed release APK + AAB:

```bash
./scripts/release/android_build_release.sh
```

## iOS

1. Ensure you have valid Apple Developer signing set up in Xcode (Certificates, Identifiers, Profiles).
2. Adjust `ios/ExportOptions.plist` as needed.
3. Build release IPA:

```bash
./scripts/release/ios_build_release.sh
```

See `docs/DEPLOYMENT_GUIDE.md` for store submission checklists.
