# Golf 101 版本控制與架構演進紀錄 (Version Control & Changelog)

本資料夾 (`VersionControl/`) 專門用於管理 **Golf 101 揮桿闖關學院** 的版本迭代紀錄、測試驗證報告與自動化驗證腳本，與 Xcode 應用程式目標 (`Golf101/`) 保持獨立分離，確保專案編譯純淨度。

---

## 一、版本演進歷史 (Release History)

### `v1.2.1` — 2026-10-23（全專案 Code Review、Debug 加固與 54 項自動化測試全數通過）
- **SwiftData 渲染純淨度修正 (`ContentView.swift`)**：移除計算屬性 `activeProfile` 內的 `modelContext.insert` 副作用，避免首次渲染重複建立 `PlayerProfile`。
- **Vision 信心度一致性與執行緒安全 (`PostureEvaluator.swift`, `CameraPreviewView.swift`, `VisionPoseDetector.swift`)**：全面統一使用 `skeleton.point(for:)` 過濾低信心度 (`< 0.15`) 關節點；為 `VisionFrameProcessor` 鏡像狀態加上 `NSLock` 執行緒鎖，並在切換前後鏡頭時清除殘留骨架。
- **防連點與邊界防呆 (`StagePlayView.swift`, `GolfGameModels.swift`, `PlayerAuthProfileView.swift`)**：加入過關領獎防重複點擊保護 (`hasClaimedReward`)、抽取 `PlayerProfile.sanitizeName` / `sanitizeBio` 統一防呆，並擴充自動化測試至 **54 / 54 項斷言全數通過**。

### `v1.2.0` — 2026-10-23（五大關卡分解步驟練習）
- **逐步姿勢訓練 (`StagePlayView`)**：五大關卡各拆成 3 個依序完成的小步驟，共 15 個練習重點；每步顯示專屬動作提示與目前指標吻合度。
- **逐步通關機制**：只有目前步驟達標並定格維持後才會解鎖下一步；完成前一步後可回看已練習步驟，最後一步完成才會結算整關星級、經驗值與觀念問答。
- **上桿分解**：拆成胸口帶動啟動、上桿保持手臂寬度、頂點穩住下盤，分別對應轉肩、前導臂延伸與 Anti-Sway 評分。

### `v1.1.0` — 2026-10-23（新增球員登入通行證、個人高球簡介與五階練習通關徽章館）
- **球員登入與個人簡介 (`PlayerLoginProfileSheet` / `PlayerAuthProfileView.swift`)**：
  - 首次啟動自動開啟「球員登入通行證設定」，並支援於主畫面頂部與導覽列隨時點擊「球員證 / 徽章」編輯個人資料。
  - 支援自訂 **球員暱稱 (`playerName`)**、**個人高球簡介／目標宣言 (`playerBio`)**（附帶一鍵快速目標標籤）與 **5 款高球代表圖章 (`avatarSymbol`)**，並提供即時球員通行證預覽卡。
- **五階練習通關榮譽徽章系統 (`PracticeBadge`)**：
  - 依據累計練習通關次數 (`totalPracticeSessions`) 與通關進度，自動計算進度百分比並解鎖五階榮譽徽章：
    1. 🥉 **初踏果嶺銅章 (`FIRST TEE ROOKIE`)**：完成 1 次練習通關
    2. 🥈 **鐵桿練習生銀章 (`RANGE REGULAR`)**：累計完成 3 次練習通關
    3. 🥇 **球道突破者金章 (`FAIRWAY BREAKER`)**：累計完成 5 次練習通關
    4. 💎 **翡翠揮桿大師章 (`EMERALD SWING PRO`)**：累計完成 10 次練習通關
    5. 👑 **大滿貫傳奇王冠 (`GRAND SLAM LEGEND`)**：累計完成 20 次練習或全數通過 5 大關卡
  - 新增徽章解鎖單元測試，全專案測試擴充至 **48 / 48 項全數通過**。

### `v1.0.0` — 2026-10-23（正式基準版：生物力學人形 + 五大關卡 AI 姿勢訂正）
- **核心功能新增**：
  - 建立 **五道高爾夫基本功闖關系統**：
    1. `Stage 1`：站姿與瞄準設定（雙腳與肩寬比、脊椎髖部前傾角、膝蓋微彎彈性角）
    2. `Stage 2`：握桿方式與虎口檢查（支援重疊式、互鎖式、十指式，含虎口 V 字雷射線與雙手緊密度）
    3. `Stage 3`：上桿與轉肩蓄力（左手前導臂延伸度、轉肩上桿高度、下盤防橫移 Anti-Sway）
    4. `Stage 4`：下桿與擊球瞬間（重心轉移左腳比例、桿身前傾雙手領先球位、頭部穩定留後）
    5. `Stage 5`：送桿與收桿平衡（左腳獨立支撐、雙手高收於左耳後、右膝靠攏左膝維持 3 秒）
  - 實作 **Vision AI 相機即時骨架偵測 (`VNDetectHumanBodyPoseRequest` + `VNDetectHumanHandPoseRequest`)** 與 **互動模擬人偶拖曳模式** 雙軌切換。
  - 實作 **中文語音教練即時播報 (`AVSpeechSynthesizer`)**、**定格集氣過關計時器**、**星級與 XP 等級晉升**、以及 **過關觀念快問快答加分題**。
- **視覺與人體比例迭代**：
  - `v0.8.0`：導入 SwingDecoded 生物力學風格（深岩灰半透明軀幹四肢膠囊、後方翠綠標準動作疊影、純白內部運動學連桿與空心圓環支點、青綠漸層揮桿光弧、紅／綠雙層警示圈與折線 HUD 診斷框）。
  - `v0.9.0`：重構無重疊安全區佈局（將頂部吻合度計時欄與底部教練指導欄移出畫布外獨立成列、引線標籤固定於兩側邊界），並放大中央人物比例至 `0.90x`。
  - `v1.0.0`：收細下半身骨盆、雙膝與腳踝跨距及大腿／小腿膠囊粗細，呈現修長運動員體態；完成開發十二黃金準則加固與 42/42 自動化測試驗證。

### `v0.1.0` — 2026-10-23（初始版本）
- 建立 Xcode 專案與基礎 SwiftData 模板 (`041d65d`)。

---

## 二、專案目錄結構與版控範圍 (Repository Structure)

```text
Golf101/
├── README.md                                  # 專案總覽與快速導覽
├── Golf101.xcodeproj/                         # Xcode 專案設定檔 (含 NSCameraUsageDescription)
├── Golf101/                                   # iOS App 主程式目標 (SwiftUI + SwiftData + Vision)
│   ├── Golf101App.swift                       # App 入口與具備防呆降級機制的 ModelContainer
│   ├── ContentView.swift                      # 闖關地圖主頁、玩家等級儀表板與握桿流派百科
│   ├── Item.swift                             # 基礎相容模型
│   ├── Models/
│   │   └── GolfGameModels.swift               # 關卡定義、骨架結構、評分結果與 SwiftData 實體
│   ├── Services/
│   │   ├── PostureEvaluator.swift             # 生物力學幾何計算與五關卡評分引擎
│   │   └── VisionPoseDetector.swift           # AVFoundation 相機與 Vision 全身/手部骨架追蹤器
│   └── Views/
│       ├── CameraPreviewView.swift            # 生物力學人形膠囊、空心支點、光弧與引線標籤畫布
│       ├── PlayerAuthProfileView.swift        # 球員登入通行證、暱稱簡介設定與五階練習徽章館
│       ├── PostureComparisonView.swift        # NG 錯誤 vs. 黃金標準姿勢自動變形對比圖鑑
│       └── StagePlayView.swift                # 闖關實測畫面、分解步驟練習、語音教練與過關問答
├── Golf101Tests/
│   └── Golf101Tests.swift                     # Swift Testing 單元測試套件
├── Golf101UITests/                            # UI 測試目標
└── VersionControl/                            # 獨立版本控制與測試報告資料夾
    ├── TEST_REPORT.md                         # 54/54 自動化測試、Code Review Debug 與生物力學驗證報告
    ├── CHANGELOG_AND_VERSION_CONTROL.md       # 版本控制紀錄與架構說明
    └── Scripts/
        └── TestRunner.swift                   # 可獨立編譯執行的命令列自動化驗證腳本
```

---

## 三、一鍵重現測試與編譯檢查指令 (Reproducible Verification Commands)

1. **執行 iOS Simulator 嚴格型別與並行檢查（0 警告、0 錯誤）**：
   ```bash
   xcrun --sdk iphonesimulator swiftc -typecheck -disable-sandbox \
     -module-cache-path /tmp/swift-module-cache \
     -target arm64-apple-ios26.2-simulator \
     -default-isolation MainActor -parse-as-library \
     Golf101/Models/GolfGameModels.swift \
     Golf101/Services/PostureEvaluator.swift \
     Golf101/Services/VisionPoseDetector.swift \
     Golf101/Views/CameraPreviewView.swift \
     Golf101/Views/PostureComparisonView.swift \
     Golf101/Views/StagePlayView.swift \
     Golf101/Views/PlayerAuthProfileView.swift \
     Golf101/ContentView.swift \
     Golf101/Golf101App.swift \
     Golf101/Item.swift
   ```

2. **編譯並執行 54 項生物力學與徽章系統自動化測試腳本**：
   ```bash
   xcrun --sdk macosx swiftc -disable-sandbox \
     -module-cache-path /tmp/swift-module-cache-mac \
     -parse-as-library \
     Golf101/Models/GolfGameModels.swift \
     Golf101/Services/PostureEvaluator.swift \
     VersionControl/Scripts/TestRunner.swift \
     -o /tmp/golf101_test_runner && /tmp/golf101_test_runner
   ```
