# 旅行地圖 App（mapmap / trip_pin_app）開發架構與 AI 協同指南

## 1. 專案概述 (Project Overview)
- **App 名稱**：旅行地圖釘選規劃 App（`pubspec.yaml` package 名稱：`trip_pin_app`，資料夾：`mapmap`）
- **支援平台**：iOS / Android（Bundle ID：`com.hana.tripPinApp`）
- **核心定位**：貼上 Google 地圖連結即可自動解析地點並釘選於自訂旅行地圖，規劃多天行程動線。

## 2. 技術棧與規範 (Tech Stack & Conventions)
- **前端框架**：Flutter（Dart SDK `^3.12.2`）
- **狀態管理**：Provider（`^6.1.2`，`ChangeNotifier` + `Consumer`），核心狀態集中於 `trip_provider.dart`
- **地圖引擎**：`flutter_map` + `latlong2`（非 Google Maps SDK，底圖為開源地圖）
- **程式碼規範**：
  - 命名：檔案 `snake_case.dart`、類別 `PascalCase`、變數/方法 `camelCase`
  - 異步一律採用 `async/await`，不可忽略未捕獲的例外
  - 地點名稱解析**嚴禁**降級為粗略視角座標；無法精確解析時回傳 `null` 由 UI 顯示紅色錯誤 Banner（詳見上層 `APP_DEVELOPMENT_STANDARDS.md` 第五節）

## 3. 資料架構與儲存 (Data Strategy)
- **敏感資訊 (Tokens)**：無使用者帳號系統，無 Token 儲存需求
- **本地設定 (Preferences)**：`SharedPreferences` 儲存行程資料、地標 Pin、使用者自訂設定
- **本地快取 / 離線 DB**：無獨立 DB，行程資料以 JSON 序列化存於 `SharedPreferences`；`lib/data/sample_data.dart` 提供首次安裝的範例資料
- **遠端資料庫**：未使用（本 App 為純本地資料，不走雲端同步）
- **雲端檔案**：未使用

## 4. 第三方 API 與整合 (Third-Party Services)
- **身分驗證**：無（App 無需登入）
- **地圖 / 定位**：
  - `flutter_map`（地圖顯示）
  - `nominatim_service.dart`：呼叫 OpenStreetMap Nominatim API 做地點名稱搜尋/地理編碼
  - `google_maps_parser.dart`：解析使用者貼上的 Google 地圖分享連結，取出地標關鍵字後交給 Nominatim 搜尋
- **分享**：`share_plus`（分享行程）、`url_launcher`（開啟原始地圖連結）
- **推播通知**：未使用
- **廣告 (AdMob)**：`google_mobile_ads`，`widgets/ad_banner_widget.dart` 提供**橫幅廣告**
  - Ad Unit ID 由 **Firebase Remote Config**（`remote_config_service.dart`，key: `map_banner_ad_unit_id`）控制，未設定時退回程式內建預設值
  - iOS/Android Debug 模式自動改用 Google 官方測試 Ad Unit ID
- **遠端設定**：`firebase_remote_config`（僅用於廣告單元覆寫，未使用 Firestore/Auth）

## 5. 目錄結構 (Directory Structure)
```text
lib/
├── data/         # sample_data.dart：首次安裝範例行程
├── models/       # 行程 / 地標 Pin 等資料模型
├── providers/    # trip_provider.dart：全域行程狀態
├── screens/      # 頁面
├── services/       # 地圖解析、地理編碼、Remote Config 等外部整合
├── utils/        # 共用工具函式
└── widgets/      # 共用元件（含地圖標籤、廣告橫幅）
```

## 6. AI 產出要求 (Rules for AI)
- 嚴格分層：Screen 不得直接呼叫 Nominatim/HTTP，一律透過 `services/` 封裝後再交給 `trip_provider.dart`。
- 安全規範：嚴禁在程式碼中寫死金鑰；本專案目前無需任何 API Key（Nominatim 為公開服務），若未來新增需金鑰的服務，一律讀取環境變數或 Remote Config，不寫死於原始碼。
- 錯誤處理：地點解析失敗須回傳 `null` 並由 UI 顯示紅色高亮錯誤 Banner（置於輸入彈窗頂部，避免被軟體鍵盤遮擋），不可讓 App 崩潰。
- UI/UX：拖曳排序、地圖視角、天數標籤等互動須遵循上層 `APP_DEVELOPMENT_STANDARDS.md` 第三、四節之詳細規範（平鋪節點清單、方向感知落點、一鍵全覽視角等）。
- 輸出品質：提供完整且具備必要型別定義的程式碼，修改行程/地標 Model 時需主動提醒更新對應的 JSON 序列化與 `trip_provider.dart` 邏輯。

## 7. GitHub 專案網址與版本規則 (Repository & Release Protocol)
- **Repo**：`https://github.com/hanaHann/trippin_map_app.git`
  - ⚠️ 注意：本機 `git remote` 目前記錄的網址中內嵌了一組 GitHub Personal Access Token（明碼存於 `.git/config`）。這組憑證等同帳號存取密碼，建議儘快在 GitHub 後台撤銷並改用 SSH 或 Keychain 憑證管理，避免 `.git/config` 外流時遭冒用。
- **版本規則**：詳見上層 `/Users/hana/app-project/APP_DEVELOPMENT_STANDARDS.md`，摘要如下：
  1. **未經使用者明確授權（如「可以推」「推一版」）前，禁止 `git commit` / `git tag` / `git push`**，僅能本機修改與驗證。
  2. 推版前必須通過：`flutter analyze`（0 issues）與 `flutter test`（100% 通過）。
  3. 版本號採 `X.Y.Z+B`：`X.Y.Z` 不可低於 App Store Connect 已上傳過的最高版本；`+B` 每次推版強制 +1。
  4. Git Tag 格式：`vX.Y.Z+B`，並同步寫入 `changelog.txt` 對應條目。
  5. `.github/workflows/tag-main.yml`、`tag-release.yml` 為既有 CI，變更前需確認不破壞既有推版流程。
  6. iOS `MinimumOSVersion` 需維持 `15.0` 以上。
