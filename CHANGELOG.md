# Changelog

## v1.1.0 — iOS Native Support

- iOS platform support: camera metadata reader (aperture, ISO, shutter, focus distance)
- ARKit Scene Depth distance measurement (iOS 14+)
- iOS CI: `build-ios` (debug unsigned) + `release-ios` (unsigned `.app`) GitHub Actions jobs
- Project renamed to FilmCam Papi across all platforms
- CI stability: Gradle proxy removed, tflite_flutter upgraded to 0.12.1

## v1.0.0 — Initial Release

- Real-time spot / center-weighted / average light metering
- Manual exposure control: aperture, shutter, ISO, EV compensation
- A / S / M priority modes with auto-exposure sync
- Live color temperature (CCT + DUV) measurement
- Hyperfocal distance and focus range engine
- Press-drag in-place picker for all camera parameters
- Film format selection: 35mm – 4×5″
- Adaptive dark theme UI for Android tablets
