# B-SAFE Flutter App

B-SAFE is a Flutter app for building safety inspection with UWB positioning and AI-assisted defect analysis.

## Current Architecture (Feature-First)

The `lib/` folder is now reorganized to keep only active features and shared layers.

```text
lib/
├── main.dart
├── core/
│   └── theme/
│       └── app_theme.dart
├── features/
│   ├── start/
│   │   └── view/
│   │       └── start_page.dart
│   └── inspection/
│       ├── providers/
│       │   └── inspection_provider.dart
│       ├── view/
│       │   └── inspection_page.dart
│       └── widgets/
│           ├── pins/
│           │   └── mobile_pin_list_sheet.dart
│           └── settings/
│               └── mobile_settings_sheet.dart
├── models/
│   ├── inspection_model.dart
│   ├── project_model.dart
│   └── uwb_model.dart
└── services/
    ├── api_service.dart
    ├── desktop_serial_service.dart
    ├── mobile_serial_service.dart
    ├── pdf_export_service.dart
    ├── uwb_service.dart
    ├── word_export_service.dart
    └── yolo_service.dart
```

## What Was Cleaned Up

The following were removed as dead code / unused screens in the current runtime flow:

- Legacy screens and modules: `home`, `monitor`, `history`, `analysis`, `settings`, `main_layout`, and old report UI pages.
- Unused providers/models/services tied to removed report flow.
- Orphan widget files not referenced by active screens.
- Empty feature folders under `lib/features` were removed.

## Active Runtime Flow

- App entry: `main.dart`
- Landing screen: `features/start/view/start_page.dart`
- Main workflow: `features/inspection/view/inspection_page.dart`

## Setup

### 1) Install dependencies

```bash
flutter pub get
```

### 2) Run

```bash
flutter run
```

### 3) Analyze

```bash
flutter analyze lib
```

## Notes

- The app currently focuses on the **Start + Inspection** workflow.
- If you want to reintroduce dashboard/history/report tabs later, add them back as isolated `features/<name>/` modules and wire routes from `start` or `inspection` intentionally.
