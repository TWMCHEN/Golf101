# Golf 101 版本控制與架構演進紀錄 (Version Control & Changelog)

本資料夾 (`VersionControl/`) 專門用於管理 **Golf 101 揮桿闖關學院** 的版本迭代紀錄、測試驗證報告與自動化驗證腳本，與 Xcode 應用程式目標 (`Golf101/`) 保持獨立分離，確保專案編譯純淨度。

---

## 一、版本演進歷史 (Release History)

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
│       ├── PostureComparisonView.swift        # NG 錯誤 vs. 黃金標準姿勢自動變形對比圖鑑
│       └── StagePlayView.swift                # 闖關實測畫面、語音教練、定格集氣與過關問答
├── Golf101Tests/
│   └── Golf101Tests.swift                     # Swift Testing 單元測試套件
├── Golf101UITests/                            # UI 測試目標
└── VersionControl/                            # 獨立版本控制與測試報告資料夾
    ├── TEST_REPORT.md                         # 42/42 自動化測試與生物力學驗證報告
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
     Golf101/ContentView.swift \
     Golf101/Golf101App.swift \
     Golf101/Item.swift
   ```

2. **編譯並執行 42 項生物力學自動化測試腳本**：
   ```bash
   xcrun --sdk macosx swiftc -disable-sandbox \
     -module-cache-path /tmp/swift-module-cache-mac \
     -parse-as-library \
     Golf101/Models/GolfGameModels.swift \
     Golf101/Services/PostureEvaluator.swift \
     VersionControl/Scripts/TestRunner.swift \
     -o /tmp/golf101_test_runner && /tmp/golf101_test_runner
   ```
