# 📱 移動端 App 開發標準與版本管理規範指南 (`hana/app-project`)

> 本規範總結自 MapMap 行程地圖 App 的開發實務，涵蓋 Git 提交守則、版本號管理、UI 拖曳架構、地圖視角控制與錯誤處理標準，適用於目錄 `hana/app-project/` 下所有 Flutter / 移動端 App 專案開發。

---

## 📂 專案目錄結構與範疇 (Project Context)

- **工作區主目錄**：`hana/app-project/`
- **適用子專案**：`hana/app-project/<project-name>` (例如 `mapmap`, `smart_fridge_app`, `cloth` 等)

---

## 📌 一、 Git 提交與推送規範 (Git Release Protocol)

1. **嚴格推版授權原則（STRICT AUTHORIZATION）**：
   * **未獲使用者明確指令（如「可以推」、「推一版」）前，絕對禁止執行 `git commit`、`git tag` 或 `git push`！**
   * 未獲授權期間，所有變更僅能在本地端檔案修改，並進行本機驗證。
2. **推版前雙重發佈驗證**：
   * 每次準備推版前，必須通過以下兩項本機指令驗證：
     - `flutter analyze`：必須 **0 issues / 0 warnings**。
     - `flutter test`：單元測試必須 **100% 全數通過**（All tests passed）。
3. **推版標準流程**：
   ```bash
   # 1. 更新版本號 (pubspec.yaml) 與 release notes (changelog.txt)
   # 2. 執行驗證
   flutter analyze && flutter test
   # 3. 提交、打 Tag 並推送
   git add .
   git commit -m "release: vX.Y.Z+B <詳細更新說明>"
   git tag vX.Y.Z+B
   git push origin main --tags
   ```

---

## 🔢 二、 版本號管理規範 (Versioning Protocol - 方案 A)

為了符合 iOS App Store 與 Android Google Play 商店的發佈標準，採用 **方案 A 語意化版本管理**：

1. **`X.Y.Z+B` 結構定義**：
   * **`X.Y.Z`（商店顯示版本號 / SemVer）**：
     * 開發與小修正期間**保持固定**（例如 `1.0.0`），避免商店版本號過度頻繁跳號。
     * 僅在正式審核上架通過或重大功能大改版時才調升 `Z` 或 `Y`。
   * **`+B`（內部建置號 / Build Number）**：
     * **每次修復或推版時，強制 +1 遞增**（例如 `1.0.0+34` ➔ `1.0.0+35` ➔ `1.0.0+36`）。
     * 滿足 Apple App Store Connect 與 Google Play Console 對上傳檔案序號不可重複的要求。
2. **標籤與紀錄一致性**：
   * Git Tag 統一格式為 `vX.Y.Z+B`（例如 `v1.0.0+34`）。
   * `changelog.txt` 條目頂端記錄對應的 `[vX.Y.Z+B]` 變更清單。

---

## 🖐️ 三、 拖曳與 UI 互動架構 (UI & Drag-and-Drop Architecture)

1. **平鋪型獨立節點清單 (Flat Node List)**：
   * 在使用 `ReorderableListView` 時，天數標頭（`_DayHeaderNode`）與景點卡片（`_LandmarkCardNode`）必須解耦為**完全獨立的 1 級 Top-Level Widget**。
   * 絕不能將天數標頭包在第一張卡片的 `Column` 內部，避免拖曳第一張卡片時天數標籤連帶浮起的視覺瑕疵。
2. **雙向方向感知落點機制 (Direction-Aware Drop Logic)**：
   * **⬇️ 向下拖曳 (Downwards)**：卡片向下拖放到「第 X 天標題列」時，自動放置於該標題列下方，成為**第 X 天的第 1 張卡片 (Pin #1)**。
   * **⬆️ 向上拖曳 (Upwards)**：卡片向上拖放到「第 X 天標題列」或前一天末尾時，自動放置於標題列上方，成為**前一天的最後一張卡片**。
3. **無雜訊極簡介面**：
   * 景點卡片上不堆疊重複的下拉選單或 redundant 圖示（如 📋 剪貼簿圖示），統一使用直覺的右側拖曳手勢（`≡`）。
4. **整天行程靈活移動**：
   * 天數標頭列提供直覺的整天操作按鈕（`▲` 上移整天、`▼` 下移整天與下拉選單對調），可一秒完成全天行程交換。

---

## 🗺️ 四、 地圖與視角呈現規範 (Map & Viewport Standards)

1. **啟動與切換自動「一鍵全覽視角」(Auto Fit-All Viewport)**：
   * App 初次開啟、載入資料或切換行程時，系統需在第一幀渲染完成後，自動計算所有地標 Pin 的聯集邊界 (`LatLngBounds`)。
   * 自動以最佳的縮放比例與邊距（Margin Padding）呈現全覽鏡頭（與點擊「一鍵全覽視角按鈕`_zoomToFitAll`」效果一致）。
2. **路線動線天數標籤 (Route Line Day Labels)**：
   * 當天數包含 2 個或以上景點時，動線連線的中點需自動標示**對應天數主題色彩**的高質感圓角標籤（例如 `第 1 天` 紅框標籤、`第 2 天` 藍框標籤）。
3. **Marker 層級與選取動態置頂 (Bring-to-Front)**：
   * 地圖 Pin 錨點精確對齊經緯度位置。
   * 當使用者點擊地圖 Pin 或車道卡片時，該景點標籤自動躍升至最上層 Z-Index，防止標籤被遮擋。

---

## 🚫 五、 店家連結解析與錯誤處理 (Link Parsing & Error Protection)

1. **多階層 Google Maps 精準轉址與座標提取引擎**：
   * **16 進制與轉義字串解算 (`!3d` / `\x213d` / `%213d`)**：解析 Google 地圖連結時，優先選用原廠經緯度標籤（含 `!3d` / `\x213d` / `%213d`），確保標籤 100% 精確防護。
   * **門牌街區優先標籤檢索 (Street-Level Exact Building Address)**：提取 `q` 參數中完整的門牌號碼（例如 `Tokyo, Taito City, Nishiasakusa, 2 Chome-27-8` ➔ `Nishiasakusa 2-27-8`），消除過去僅靠 7 碼郵區導致 Pin 點落在 200m 外郵區中心的問題，100% 直擊目標建築。
   * **智能分詞與房號過濾 (Tokenized Geocoding & Room Cleaning)**：自動過濾「401號室」、「4階」等房間號碼雜訊，自動切分長景點名稱備援，防止跳至遠方區公所。
   * **拒絕粗略視角座標降級**：嚴格優先選用明確 POI 座標，**絕對禁止降級定位到使用者家裡、IP 預設鏡頭或粗略視角座標（`viewport_coords`）**。無法精確解析時回傳 `null` 並由 UI 提示「無法解析此連結」。
2. **全頁面紅色高亮錯誤 Banner**：
   * 搜尋或解析失敗時，在輸入彈窗內頂部顯示顯眼的紅色 Callout Banner，避免錯誤訊息被彈窗或系統軟體鍵盤遮擋。
