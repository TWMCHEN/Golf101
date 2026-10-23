# Golf 101 揮桿闖關學院 🏌️‍♂️

專為高爾夫初學者打造的 **AI 骨架偵測與姿勢訂正闖關遊戲（iOS SwiftUI + Vision + SwiftData）**。透過「站姿設定、握桿檢查、上桿轉肩、下桿擊球、送桿收桿」五道循序漸進的關卡，結合生物力學人形膠囊視覺、即時角度分析與中文語音教練指導，協助初學者建立正確揮桿地基。

---

## 📂 版本控制與測試文件導覽 (`VersionControl/`)

- 📄 **[自動化測試與生物力學驗證報告 (`VersionControl/TEST_REPORT.md`)](./VersionControl/TEST_REPORT.md)**：包含 42/42 項全數通過的關卡指標實測數據、三大握桿流派驗證、幾何邊界測試與開發十二黃金準則稽核表。
- 📘 **[版本控制與架構演進紀錄 (`VersionControl/CHANGELOG_AND_VERSION_CONTROL.md`)](./VersionControl/CHANGELOG_AND_VERSION_CONTROL.md)**：記錄 `v0.1.0` 至 `v1.0.0` 的功能與視覺迭代、目錄架構與一鍵重現測試指令。
- 🧪 **[獨立驗證腳本 (`VersionControl/Scripts/TestRunner.swift`)](./VersionControl/Scripts/TestRunner.swift)**：可於終端機直接編譯並執行全套生物力學評分驗證。
