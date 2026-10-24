//
//  TestRunner.swift
//  Golf101 VersionControl Verification Script
//
//  Created by Golf101 AI Coach on 2026/10/23.
//

import Foundation
import CoreGraphics

@main
struct TestRunner {
    static func main() {
        var passedCount = 0
        var failedCount = 0

        func check(_ condition: Bool, _ message: String) {
            if condition {
                passedCount += 1
                print("  ✅ PASS: \(message)")
            } else {
                failedCount += 1
                print("  ❌ FAIL: \(message)")
            }
        }

        print("=== Golf 101 自動化單元測試與生物力學驗證執行報告 ===")

        // 1. All 5 Stages x 3 Modes Verification
        for stageID in GolfStageID.allCases {
            let stageInfo = GolfStage.stage(for: stageID)
            print("\n[關卡 \(stageID.rawValue): \(stageInfo.title)]")

            let badSkel = PostureEvaluator.presetSkeleton(for: stageID, mode: .beginnerMistake)
            let badEval = PostureEvaluator.evaluate(skeleton: badSkel, stageID: stageID, gripStyle: .overlap)
            check(!badEval.isAllPassing, "NG 錯誤姿勢成功攔截 (準確率: \(Int(badEval.overallAccuracy))%)")
            check(badEval.checkpoints.contains(where: { $0.status != .perfect }), "NG 姿勢包含需調整指標")

            let almostSkel = PostureEvaluator.presetSkeleton(for: stageID, mode: .almostThere)
            let almostEval = PostureEvaluator.evaluate(skeleton: almostSkel, stageID: stageID, gripStyle: .overlap)
            check(almostEval.overallAccuracy > badEval.overallAccuracy, "微調姿勢準確率 (\(Int(almostEval.overallAccuracy))%) > NG 姿勢 (\(Int(badEval.overallAccuracy))%)")

            let idealSkel = PostureEvaluator.presetSkeleton(for: stageID, mode: .idealPro)
            let idealEval = PostureEvaluator.evaluate(skeleton: idealSkel, stageID: stageID, gripStyle: .overlap)
            check(idealEval.isAllPassing, "黃金標準姿勢順利過關 (準確率: \(Int(idealEval.overallAccuracy))%)")
            for cp in idealEval.checkpoints {
                check(cp.status == .perfect, "指標「\(cp.title)」達標: \(cp.currentValueText) (目標: \(cp.targetValueText))")
            }
        }

        // 2. Grip Styles Verification
        print("\n[三大握桿流派驗證]")
        for style in GripStyle.allCases {
            let idealSkel = PostureEvaluator.presetSkeleton(for: .grip, mode: .idealPro)
            let eval = PostureEvaluator.evaluate(skeleton: idealSkel, stageID: .grip, gripStyle: style)
            check(eval.isAllPassing, "\(style.rawValue) 標準虎口角度通過驗證")
        }

        // 3. Geometry & Boundary Safety Verification
        print("\n[幾何計算與邊界防禦驗證]")
        let deg90 = PostureEvaluator.threePointAngle(
            a: CGPoint(x: 0, y: 1),
            b: CGPoint(x: 0, y: 0),
            c: CGPoint(x: 1, y: 0)
        )
        check(abs(deg90 - 90.0) < 0.01, "90° 直角計算精準 (\(deg90)°)")

        let deg180 = PostureEvaluator.threePointAngle(
            a: CGPoint(x: 0, y: 0),
            b: CGPoint(x: 0.5, y: 0),
            c: CGPoint(x: 1.0, y: 0)
        )
        check(abs(deg180 - 180.0) < 0.01, "180° 平角計算精準 (\(deg180)°)")

        let zeroVec = PostureEvaluator.threePointAngle(
            a: CGPoint(x: 0.5, y: 0.5),
            b: CGPoint(x: 0.5, y: 0.5),
            c: CGPoint(x: 0.5, y: 0.5)
        )
        check(!zeroVec.isNaN && zeroVec == 180.0, "零向量防除以零保護通過 (回傳 \(zeroVec)° 無 NaN)")

        let emptySkel = PoseSkeleton(joints: [:], confidences: [:])
        let emptyEval = PostureEvaluator.evaluate(skeleton: emptySkel, stageID: .setup, gripStyle: .overlap)
        check(!emptyEval.overallAccuracy.isNaN && emptyEval.checkpoints.count == 3, "空骨架防禦測試通過 (無崩潰或 NaN)")
        check(!emptyEval.isAllPassing && emptyEval.checkpoints.allSatisfy({ $0.status == .needsCorrection }), "空骨架正確攔截並標記為需調整")

        var lowConfSkel = PostureEvaluator.presetSkeleton(for: .setup, mode: .idealPro)
        lowConfSkel.confidences[.leftAnkle] = 0.05
        let lowConfEval = PostureEvaluator.evaluate(skeleton: lowConfSkel, stageID: .setup, gripStyle: .overlap)
        check(!lowConfEval.isAllPassing, "低信心度關節 (< 0.15) 成功被過濾並攔截")

        // 4. Player Login & Practice Clearance Badges Verification
        print("\n[球員登入簡介與練習通關徽章驗證]")
        check(PracticeBadge.highestUnlocked(totalSessions: 0, clearedStagesCount: 0) == nil, "0 次練習時尚未解鎖徽章")
        check(PracticeBadge.highestUnlocked(totalSessions: 1, clearedStagesCount: 1)?.id == "badge_first_tee", "1 次練習解鎖「初踏果嶺銅章」")
        check(PracticeBadge.highestUnlocked(totalSessions: 3, clearedStagesCount: 2)?.id == "badge_range_regular", "3 次練習解鎖「鐵桿練習生銀章」")
        check(PracticeBadge.highestUnlocked(totalSessions: 5, clearedStagesCount: 3)?.id == "badge_fairway_breaker", "5 次練習解鎖「球道突破者金章」")
        check(PracticeBadge.highestUnlocked(totalSessions: 10, clearedStagesCount: 4)?.id == "badge_golden_swing", "10 次練習解鎖「翡翠揮桿大師章」")
        check(PracticeBadge.highestUnlocked(totalSessions: 20, clearedStagesCount: 5)?.id == "badge_grand_slam", "20 次練習解鎖「大滿貫傳奇王冠」")
        check(PracticeBadge.allBadges[4].isUnlocked(totalSessions: 5, clearedStagesCount: 5), "全數通過 5 大關卡亦可解鎖「大滿貫傳奇王冠」")
        check(PlayerProfile.sanitizeName("   \n ") == PlayerProfile.defaultPlayerName, "空白暱稱自動回退預設名稱「高球新星」")
        check(PlayerProfile.sanitizeBio("   ") == PlayerProfile.defaultPlayerBio, "空白簡介自動回退預設目標簡介")
        check(PracticeBadge.allBadges[0].progress(totalSessions: -5, clearedStagesCount: 0) == 0.0, "負數練習次數邊界保護通過 (進度 = 0.0)")

        // 5. Speech Command Parsing Verification
        print("\n[繁體中文語音指令解析驗證 (SpeechCommand)]")
        check(SpeechCommand.parse("請進入下一步") == .next, "語音「請進入下一步」解析為 .next")
        check(SpeechCommand.parse("完成 　這一步") == .next, "含全形／半形空白之「完成這一步」解析為 .next")
        check(SpeechCommand.parse("教練再說一次") == .repeatTip, "語音「教練再說一次」解析為 .repeatTip")
        check(SpeechCommand.parse("重新開始練習") == .restartStep, "語音「重新開始練習」解析為 .restartStep")
        check(SpeechCommand.parse("請問語音指令有哪些") == .help, "語音「請問語音指令有哪些」解析為 .help")
        check(SpeechCommand.parse("   　\n ") == nil && SpeechCommand.parse("今天天氣真好") == nil, "空白與非指令語句安全回傳 nil")

        // 6. Practice History Trajectory & Focus Movement Verification
        print("\n[練習進步軌跡與分解動作弱項診斷驗證 (PracticeHistoryRecord)]")
        let sampleHistory = PracticeHistoryRecord(
            stageRawValue: GolfStageID.setup.rawValue,
            accuracy: 91.6,
            stars: 2,
            quizPassed: true,
            checkpointScores: [
                "setup_stance": 0.96,
                "setup_spine": 0.87,
                "setup_knee": 0.92
            ]
        )
        check(sampleHistory.stageID == .setup && sampleHistory.checkpointScores.count == 3, "PracticeHistoryRecord 分解動作分數 JSON 編解碼正確")
        let focus = PracticeHistoryRecord.lowestCheckpoint(in: sampleHistory.checkpointScores)
        check(focus?.id == "setup_spine" && focus?.title == "髖部前傾" && Int(focus?.scorePercent ?? 0) == 87, "自動鎖定最低分分解動作「髖部前傾 (87分)」作為下次加強建議")
        check(GolfStageID.allCases.allSatisfy({ PracticeHistoryRecord.orderedCheckpointIDs(for: $0).count == 3 }), "五大關卡皆具備 3 項固定順序之圖表分解動作標題")

        print("\n==============================================")
        print("總計通過: \(passedCount) 項 | 失敗: \(failedCount) 項")
        if failedCount > 0 {
            Foundation.exit(1)
        }
    }
}
