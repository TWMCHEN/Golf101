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

        print("\n==============================================")
        print("總計通過: \(passedCount) 項 | 失敗: \(failedCount) 項")
        if failedCount > 0 {
            Foundation.exit(1)
        }
    }
}
