# SmartSurvey Flutter App

SmartSurvey is a Flutter app for building safety inspection with UWB positioning and AI-assisted analysis.

This repository now follows a Feature-Based + Clean Architecture direction:
- `core`: app-wide infrastructure
- `features`: business modules, each owning its own domain/data/presentation code where applicable
- `shared`: only cross-feature models/services that are still used by multiple features

## Current Project Structure

```text
lib/
├── main.dart
├── app.dart
├── core/
│   └── theme/
│       └── app_theme.dart
├── features/
│   ├── start/
│   │   └── presentation/
│   │       └── views/
│   │           └── start_page.dart
│   ├── inspection/
│   │   ├── data/
│   │   │   └── services/
│   │   │       ├── desktop_serial_service.dart
│   │   │       ├── mobile_serial_service.dart
│   │   │       ├── pdf_export_service.dart
│   │   │       ├── uwb_service.dart
│   │   │       └── word_export_service.dart
│   │   ├── domain/
│   │   │   └── entities/
│   │   │       ├── inspection_model.dart
│   │   │       └── uwb_model.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── inspection_provider.dart
│   │       ├── views/
│   │       │   └── inspection_page.dart
│   │       └── widgets/
│   │           ├── pins/
│   │           │   └── inspection_pin_list_bottom_sheet.dart
│   │           └── settings/
│   │               └── inspection_settings_bottom_sheet.dart
│   └── ai_analysis/
│       ├── data/
│       │   ├── datasources/
│       │   │   └── ai_datasource.dart
│       │   ├── models/
│       │   │   └── detection_result_model.dart
│       │   ├── repositories/
│       │   │   └── ai_repository_impl.dart
│       │   └── services/
│       │       └── ai_analysis_service.dart
│       ├── domain/
│       │   ├── entities/
│       │   │   └── detection_result_entity.dart
│       │   ├── repositories/
│       │   │   └── ai_repository.dart
│       │   └── usecases/
│       │       └── perform_detection_usecase.dart
│       └── presentation/
│           ├── providers/
│           │   └── ai_provider.dart
│           ├── views/
│           │   └── ai_analysis_page.dart
│           └── widgets/
│               ├── ai_settings_sheet.dart
│               └── detection_result_overlay.dart
└── shared/
    ├── models/
    │   └── project_model.dart
    └── services/
        ├── api_service.dart
        └── yolo_service.dart
```

## Feature Ownership

- `start`: app entry landing flow.
- `inspection`: UWB, serial communication (desktop/mobile), floor plan interaction, pin/anchor workflows, report export.
- `ai_analysis`: AI detection and AI-assisted analysis pipeline with domain/data/presentation layering.

## Shared Layer Policy

`lib/shared` is intentionally small and reserved for cross-feature code only.

Current shared assets:
- `project_model.dart`: consumed across modules.
- `api_service.dart`: network/AI API utility used by both `inspection` and `ai_analysis`.
- `yolo_service.dart`: YOLO abstraction used by both `inspection` and `ai_analysis`.

If a file becomes feature-specific, move it into that feature and update imports.

## Getting Started

### Prerequisites

- Flutter SDK (Dart SDK included)
- Platform toolchains for your target (Android/Linux/Web/etc.)

### Install dependencies

```bash
flutter pub get
```

### Run

```bash
flutter run
```

### Static analysis

```bash
flutter analyze --no-preamble
```

## YOLO Model Configuration

This section explains exactly where to change the YOLO model and what each location controls.

### 1) Put your model file in assets

- Folder: `assets/models/`
- Example model file: `assets/models/my_model.tflite`

The project already includes this asset folder in `pubspec.yaml`:

```yaml
flutter:
    assets:
        - assets/models/
```

If you add or replace model files, run:

```bash
flutter pub get
```

### 2) Change the default model name used by YOLO service

Edit:
- `lib/shared/services/yolo_service.dart`

Update this constant:

```dart
static const String _defaultCustomModel = 'best_float32';
```

Change `'best_float32'` to your model key/name.

Notes:
- Keep the name consistent with how your YOLO plugin/service resolves model identifiers.
- In many setups, this value is the model name without extension.

### 3) Override model per screen (optional)

If you want one screen to use a different model than the global default, edit:
- `lib/features/inspection/presentation/views/inspection_page.dart`

Current call:

```dart
final loaded = await YoloService.instance.loadModel();
```

Override call example:

```dart
final loaded = await YoloService.instance.loadModel(
    modelPath: 'my_model',
);
```

### 4) Verify runtime support

Current compatibility mode in:
- `lib/shared/services/yolo_service.dart`

This line indicates YOLO runtime is currently disabled:

```dart
static bool get isSupported => false;
```

Important:
- If `isSupported` is `false`, changing model names will not enable live YOLO detection by itself.
- To actually run a new model, YOLO runtime support must be enabled and implemented for your target platform.

### 5) Quick test checklist after changing model

1. Confirm file exists in `assets/models/`.
2. Confirm `pubspec.yaml` still includes `assets/models/`.
3. Run `flutter pub get`.
4. Run `flutter analyze --no-preamble`.
5. Run the app with `flutter run` and check YOLO model load logs.

## Platform Notes

- Desktop serial communication uses `flutter_libserialport`.
- Android USB serial communication uses `usb_serial`.
- YOLO runtime currently follows a compatibility-safe implementation path in `yolo_service.dart`.

## Next Refactor Targets

- Continue moving inspection business logic from presentation/provider into explicit domain use cases.
- Keep shrinking `shared` to only true cross-feature dependencies.
