# B-SAFE Flutter App

智慧城市建築安全應用 - Flutter 前端（**Feature-First 架構**）

## 功能特點

### ✅ 已實現功能

1. **UWB 定位系統** 📡
   - 超寬帶實時位置追蹤
   - 精準建築物內導航
   - 多錨點校準

2. **檢查工作流** 🏗️
   - 樓層平面圖上標記問題點
   - AI 分析缺陷照片
   - 實時風險評分（0-100）

3. **缺陷上報** 📸
   - 相機拍照 / 相簿選取
   - 類別分類（結構、外牆、電氣、水管等）
   - AI 自動評估嚴重程度

4. **智能 AI 分析** 🤖
   - POE API / 本地離線評估
   - 損壞類型識別
   - 緊急程度自動判斷

5. **數據分析儀表板** 📊
   - 風險分佈圖表
   - 近期趨勢可視化
   - 統計卡片

6. **在線/離線支持** 🔄
   - 自動網絡檢測
   - SQLite 本地緩存
   - 恢復連線自動同步

## 架構設計

### Feature-First 結構（模塊化架構）

```
lib/
├── core/                           # 核心層
│   ├── theme/
│   │   └── app_theme.dart         # 全局主題
│   └── providers/
│       └── connectivity_provider.dart  # 全局連接狀態
│
├── features/                       # 特性模塊層
│   ├── start/                      # 啟動/項目選擇
│   │   ├── view/
│   │   │   └── start_page.dart
│   │   └── widgets/
│   │
│   ├── main_layout/                # 應用殼層 (底部導航)
│   │   ├── view/
│   │   │   └── main_screen.dart
│   │   ├── controller/
│   │   │   └── main_layout_controller.dart
│   │   └── providers/
│   │       └── navigation_provider.dart
│   │
│   ├── home/                       # 首頁儀表板
│   │   ├── view/
│   │   │   └── home_page.dart
│   │   └── widgets/
│   │       ├── stat_card.dart
│   │       ├── recent_report_card.dart
│   │       ├── animated_counter.dart
│   │       └── shimmer_loading.dart
│   │
│   ├── inspection/                 # UWB 檢查工作流
│   │   ├── view/
│   │   │   ├── inspection_page.dart
│   │   │   └── calibration_page.dart
│   │   ├── widgets/
│   │   │   ├── pins/
│   │   │   │   └── mobile_pin_list_sheet.dart
│   │   │   └── settings/
│   │   │       └── mobile_settings_sheet.dart
│   │   └── providers/
│   │       └── inspection_provider.dart
│   │
│   ├── monitor/                    # UWB 數據監控
│   │   ├── view/
│   │   │   └── monitor_page.dart
│   │   └── widgets/
│   │       ├── position_canvas.dart
│   │       ├── settings_panel.dart
│   │       └── data_tables.dart
│   │
│   ├── report/                     # 缺陷上報
│   │   ├── view/
│   │   │   └── report_page.dart
│   │   ├── widgets/
│   │   │   ├── ai_analysis_result.dart
│   │   │   ├── category_selector.dart
│   │   │   └── severity_selector.dart
│   │   └── providers/
│   │       └── report_provider.dart
│   │
│   ├── history/                    # 報告歷史
│   │   ├── view/
│   │   │   ├── history_page.dart
│   │   │   └── report_detail_page.dart
│   │   └── widgets/
│   │       └── report_detail_card.dart
│   │
│   ├── analysis/                   # 數據分析
│   │   └── view/
│   │       └── analysis_page.dart
│   │
│   └── settings/                   # 應用設置
│       └── view/
│           └── settings_page.dart
│
├── models/                         # 全局數據模型
│   ├── project_model.dart
│   ├── report_model.dart
│   ├── inspection_model.dart
│   └── uwb_model.dart
│
├── services/                       # 全局業務服務
│   ├── api_service.dart           # API 與 AI 集成
│   ├── database_service.dart      # SQLite 本地存儲
│   ├── uwb_service.dart           # UWB 通信
│   ├── desktop_serial_service.dart
│   ├── mobile_serial_service.dart
│   └── yolo_service.dart          # YOLO 本地推理
│
├── main.dart                       # 應用入口
└── providers/                      # 空 (遷移至 features)
```

## 核心概念

### 特性模塊職責

每個 `features/<feature>/` 擁有：
- **view/** - 主要頁面 (`*_page.dart`)
- **widgets/** - 特性專屬 UI 組件（非共享）
- **controller/** - 本地狀態邏輯
- **providers/** - 特性狀態管理（可選）

### 分層設計

| 層級 | 職責 | 示例 |
|------|------|------|
| **core/** | 全局主題、連接狀態 | `app_theme.dart`、`connectivity_provider.dart` |
| **features/** | 功能模塊、UI、狀態 | `inspection/`、`report/` |
| **services/** | 邏輯服務、API、數據庫 | `api_service.dart`、`uwb_service.dart` |
| **models/** | 數據結構 | `ReportModel`、`InspectionSession` |

## 主要特性模塊

### 🏠 **home** - 儀表板
- 統計卡片（高/中/低風險計數）
- 最近上報列表
- 實時動畫計數器

### 🔍 **inspection** - UWB 檢查工作流
- 平面圖顯示與交互
- 缺陷點標記 (`InspectionPin`)
- 底部表單（類別、嚴重程度）
- AI 分析觸發
- 校準頁面

### 📍 **monitor** - UWB 實時監控
- 位置畫布渲染
- 設置面板
- 數據表格

### 📝 **report** - 缺陷上報
- 圖片選取 + 預覽
- 類別與嚴重程度選擇
- AI 分析結果展示
- 在線/離線模式切換

### 📊 **history** - 報告瀏覽
- 列表篩選
- 詳情頁面
- 狀態/風險級別標籤

### ⚙️ **main_layout** - 應用殼層
- 底部導航條（首頁 / 監控 / 設置）
- Tab 切換狀態管理
- 全局儀表板

## 安裝和運行

### 1. 安裝依賴

```bash
flutter pub get
```

### 2. 配置 POE API

在 `lib/services/api_service.dart` 設置 API Key：

```dart
static const String poeApiKey = 'YOUR_POE_API_KEY';
```

### 3. 運行應用

```bash
# 調試模式
flutter run

# 特定設備
flutter run -d <device_id>

# 構建 APK
flutter build apk --release

# 構建 iOS
flutter build ios --release
```

### 4. 代碼分析

```bash
# 檢查代碼質量
flutter analyze lib

# 格式化 Dart 代碼
dart format lib/
```

## 技術棧

| 技術 | 用途 |
|------|------|
| **Flutter 3.x** | 跨平台 UI 框架 |
| **Provider** | 狀態管理 |
| **sqflite** | 本地 SQLite 數據庫 |
| **connectivity_plus** | 網絡狀態檢測 |
| **image_picker** | 圖片選取 |
| **fl_chart** | 圖表可視化 |
| **pdfrx** | PDF 樓層平面圖 |
| **http** | HTTP 請求 |

## 開發指南

### 添加新特性模塊

```
lib/features/my_feature/
├── view/
│   └── my_feature_page.dart     # 主頁面
├── widgets/                      # 本地 UI 組件
├── controller/                   # 狀態邏輯
├── providers/                    # 狀態管理（可選）
└── models/                       # 特性專屬模型（可選）
```

### 命名約定

- **頁面**: `*_page.dart` (如 `home_page.dart`)
- **提供者**: `*_provider.dart` (如 `report_provider.dart`)
- **控制器**: `*_controller.dart` (如 `main_layout_controller.dart`)
- **組件**: `*_widget.dart` 或描述性名稱 (如 `stat_card.dart`)

### 導入規則

```dart
// ✅ 推薦：完整路徑
import 'package:bsafe_app/features/home/widgets/stat_card.dart';
import 'package:bsafe_app/core/theme/app_theme.dart';
import 'package:bsafe_app/services/api_service.dart';

// ❌ 避免：相對導入
import '../../../widgets/stat_card.dart';
```

## 下一步：後端開發

前端架構已完成，接下來需要開發：

1. **REST API** - Node.js / PHP 後端服務
2. **數據庫** - MariaDB / PostgreSQL
3. **雲存儲** - 圖片 / PDF 存儲
4. **AI 服務** - POE API / 本地模型部署

## 許可證

MIT License
