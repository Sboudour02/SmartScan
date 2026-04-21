# SmartScan

A robust, feature-rich barcode and QR code scanner and generator application for Android built with Flutter.

## Features

- **Barcode/QR Scanner:** Lightning-fast scanning with custom camera overlay, haptic feedback, and beep sounds.
- **Generator Mode:** Create various formats (QR Code, EAN-13, EAN-8, UPC-A, ITF-14, Code 39, Code 128, etc.).
- **Batch Generator:** Generate bulk QR codes or barcodes by uploading CSV or Excel (.xlsx) files.
- **History Tracking:** Save your scanned and generated items locally. Items can be searched, deleted, or shared.
- **Intelligent Routing:** Automatically identifies URLs, WiFi networks, and email formats for one-tap actions.
- **Exporting Options:** Export single or batch-generated barcodes as PNG or PDF.

## Security & Privacy Enhancements

- **Strict URL Validation:** Prevents interaction with URLs featuring unsafe schemes or suspicious regex patterns.
- **File Management:** Automatic cleanup of old, temporary export files to prevent storage bloat.
- **Dependency Tracking:** Security configuration audits utilizing up-to-date versions of plugins.
- **Secrets Management:** Integrates Shorebird Tokens via GitHub Actions Secrets instead of local hardcoding to avoid exposure.

## CI/CD Pipeline

The project integrates GitHub Actions to automate Continuous Integration and Deployment.
- **Automated Builds:** Pull Requests to the `main` branch trigger linting (`flutter analyze`), testing, and Android APK builds.
- **Shorebird OTA Updates:** Continuous deployment uses Shorebird to push Over-The-Air (OTA) patches seamlessly to user devices without requiring a full Play Store update. This leverages GitHub Actions secrets to securely deploy patches automatically on the main branch.

## Run Locally

To get started with SmartScan:

1. Clone the repository and navigate into it.
2. Run `flutter pub get` to install all dependencies.
3. Use a physical Android device or an emulator.
4. Run `flutter run` to launch the application.

## Packages / Plugins

Significant dependencies include:
- `mobile_scanner` for barcode reading.
- `barcode_widget` & `qr_flutter` for code generation.
- `file_picker` & `excel` for processing batch data.
- `file_saver`, `share_plus`, and `pdf` for export implementations.
- `shared_preferences` & `vibration`/`audioplayers` for local caching and haptics.
