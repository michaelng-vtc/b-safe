# B-SAFE Flutter App

B-SAFE is a Flutter app for building safety inspection with UWB positioning and AI-assisted defect analysis.

> 中文說明：目前專案已整理為「Feature-First + Clean Architecture 導向」結構，方便後續擴展與分層維護。

## Architecture / 架構

The `lib/` folder is organized with explicit boundaries: `core` (global infra), `shared` (cross-feature reusable code), and `features` (business modules).

> 中文註解：
> - `core`：全域基礎層（不依賴特定業務）
> - `shared`：跨 feature 共用
> - `features`：業務模組（start / inspection）

```text
lib/
├── main.dart
├── app.dart                          # App 啟動組裝（DI/Theme/入口頁）
│
├── core/                             # 全域基礎設施
│   ├── constants/
│   ├── di/
│   ├── extensions/
│   ├── router/
│   ├── theme/
│   │   └── app_theme.dart
│   └── utils/
│
├── shared/                           # 跨 feature 共用
│   ├── models/
│   │   ├── inspection_model.dart
│   │   ├── project_model.dart
│   │   └── uwb_model.dart
│   ├── services/
│   │   ├── api_service.dart
│   │   ├── desktop_serial_service.dart
│   │   ├── mobile_serial_service.dart
│   │   ├── pdf_export_service.dart
│   │   ├── uwb_service.dart
│   │   ├── word_export_service.dart
│   │   └── yolo_service.dart
│   └── widgets/
│
└── features/                         # 業務功能模組
	├── start/
	│   ├── data/
	│   ├── domain/
	│   └── presentation/
	│       └── views/
	│           └── start_page.dart
	│
	└── inspection/
		├── data/
		│   ├── datasources/
		│   ├── mappers/
		│   ├── models/
		│   └── repositories/
		├── domain/
		│   ├── entities/
		│   ├── repositories/
		│   └── usecases/
		└── presentation/
			├── providers/
			│   └── inspection_provider.dart
			├── views/
			│   └── inspection_page.dart
			└── widgets/
				├── pins/
				│   └── inspection_pin_list_bottom_sheet.dart
				└── settings/
					└── inspection_settings_bottom_sheet.dart
```

## Current Runtime Flow / 目前執行流程

- App entry: `main.dart`
- App composition: `app.dart`
- Landing page: `features/start/presentation/views/start_page.dart`
- Main workflow: `features/inspection/presentation/views/inspection_page.dart`

> 中文註解：目前主流程聚焦在 **Start + Inspection**，其餘歷史/儀表板模組已清理。

## Setup / 開發與執行

### 1) Install dependencies / 安裝依賴

```bash
flutter pub get
```

### 2) Run app / 執行 App

```bash
flutter run
```

### 3) Analyze / 靜態檢查

```bash
flutter analyze --no-preamble
```

## Notes / 備註

- `data/domain` folders are scaffolded for incremental extraction of entities, repositories, and use cases.
- Shared models/services are intentionally centralized under `lib/shared` to reduce cross-feature duplication.

> 中文補充：下一步建議先從 `inspection` 開始，逐步把 provider 內商業邏輯下沉到 `domain/usecases`。
