# SignSync v1.0.0 Release Notes

**Release:** 1.0.0 (Build 1)

## Highlights
- Real-time **ASL translation** workflows (camera-based and text-to-ASL)
- **Object detection** with spoken alerts and accessibility-focused UX
- **Sound detection** with configurable alerts
- Optional **AI assistant** experience
- Extensive in-app help, onboarding, and troubleshooting content

## What’s New
### Accessibility & UX
- High contrast mode
- Adjustable text scaling
- Onboarding and help screens built into the app

### ASL Translation
- Text-to-ASL translation with dictionary/fingerspelling fallback
- ASL-to-text pipeline via orchestrated ML services (architecture-ready)

### Object Detection
- Detection overlays and confidence thresholds
- Spoken alerts integration (TTS)

### Sound Alerts
- Noise events visualization
- Alert settings and permissions UX

## Release Engineering
- App version set to **1.0.0+1** in `pubspec.yaml`
- Release logging hardened (debug logs suppressed in release)
- Android release Gradle configuration added with:
  - R8/ProGuard minification
  - resource shrinking
  - debug symbol stripping configuration
- Release scripts added under `scripts/release/`

## Known Limitations
- Some ML components are implemented as production-ready scaffolding; real model assets and tuned thresholds should be validated per device class.
- Release code signing requires project-specific credentials (not included in repository).

## Upgrade Notes
- Android signing requires creating `android/key.properties` (see `docs/DEPLOYMENT_GUIDE.md`).
- iOS signing requires Apple Developer certificates/profiles configured in Xcode.

## Roadmap
- Expanded ASL sign library (500+ signs) with improved NLP and phrase handling
- Improved model update mechanism and telemetry (opt-in)
- Full localization coverage for store listings and in-app content
