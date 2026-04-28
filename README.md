# SmartSurvey

SmartSurvey is a Flutter application for building safety inspection workflows with floor-plan pin mapping, UWB-assisted positioning, and AI-based defect analysis.

Current app version: `1.0.0+1`

## What Is New In This Version

- Unified project-based workflow from app start to inspection session.
- Multi-floor inspection flow with per-floor session management.
- UWB anchor configuration and live tag coordinate display.
- AI analysis screen with YOLO detection and structured defect context fields.
- Word and PDF export actions directly from inspection.
- Responsive layout optimized for desktop and mobile form factors.

## Core Capabilities

- Create, open, and delete building projects.
- Manage floor-specific inspection sessions and pin records.
- Add and organize inspection pins on floor plans.
- Configure UWB anchors and serial connection settings.
- Use AI analysis to detect defects from images.
- Export inspection data to Word/PDF and share output files.

## Tech Stack

- Flutter + Dart (SDK `>=3.0.0 <4.0.0`)
- State management: `provider`
- Local persistence: `shared_preferences`, `sqflite`
- File/image handling: `file_picker`, `image_picker`, `image`
- AI inference: `tflite_flutter`
- Connectivity and device I/O: `connectivity_plus`, `usb_serial`, `flutter_libserialport`, `flutter_blue_plus`
- Reporting and sharing: `pdf`, `pdfrx`, `share_plus`

## Project Structure

```text
lib/
  app.dart
  main.dart
  core/
  features/
    start/
    inspection/
    ai_analysis/
  shared/
```

Feature ownership:

- `start`: project entry and project list lifecycle.
- `inspection`: floor plan, pins, UWB/serial integration, export workflow.
- `ai_analysis`: image-driven defect analysis and detection UI.
- `shared`: code reused across multiple features (models/services).

## Getting Started

### Prerequisites

- Flutter SDK installed and available in `PATH`
- Platform toolchain for your target device (Android/Linux/Web/etc.)

### Install Dependencies

```bash
flutter pub get
```

### Run The App

```bash
flutter run
```

### Analyze

```bash
flutter analyze --no-preamble
```

## Platform Notes

- Desktop serial integration uses `flutter_libserialport`.
- Android OTG serial integration uses `usb_serial`.
- PDF floor-plan viewing initializes in `main.dart` via `pdfrxFlutterInitialize()`.

## AI / YOLO Setup

The default model and labels are loaded from:

- `assets/models/yolo.tflite`
- `assets/models/labels.txt`

If you replace model files, run:

```bash
flutter pub get
```

### VLM API Key

Add your Gemini API key to the root `local.properties` file:

```properties
ai.apiKey=YOUR_GEMINI_API_KEY
```

The app reads this value through a Flutter asset, so it works on Android, iOS, desktop, and web builds that bundle assets.

### Linux TensorFlow Lite Runtime

For Linux desktop, `tflite_flutter` requires a shared library in `blobs/`.

Build and place it automatically with:

```bash
bash scripts/download_tflite_linux.sh
```

This script generates:

- `blobs/libtensorflowlite_c-linux.so`

## Troubleshooting

### Linux build uses stale CMake path

Symptom:

- Linux build fails after moving/renaming the project directory.
- `build/linux/x64/debug/CMakeCache.txt` references an old path.

Fix:

```bash
rm -rf build/linux
flutter build linux
```

### AI model does not load

Check:

- Model file exists at `assets/models/yolo.tflite`
- Labels file exists at `assets/models/labels.txt`
- `flutter pub get` completed successfully

## Recommended Commands

```bash
# Get dependencies
flutter pub get

# Run on connected device
flutter run

# Analyze code
flutter analyze --no-preamble

# Run tests
flutter test

# Build Linux app
flutter build linux
```

## License

No license file is currently defined in this repository.
