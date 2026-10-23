//
//  Golf101Tests.swift
//  Golf101Tests
//
//  Created by Hsiaoyi Chen on 2026/10/23.
//

import Testing
import CoreGraphics
@testable import Golf101

@MainActor
struct Golf101Tests {

    @Test("五道關卡：NG 錯誤姿勢應被攔截，黃金標準姿勢應全數通過")
    func allStagesRejectBeginnerMistakesAndPassIdealPoses() async throws {
        for stageID in GolfStageID.allCases {
            let badSkeleton = PostureEvaluator.presetSkeleton(for: stageID, mode: .beginnerMistake)
            let badEval = PostureEvaluator.evaluate(
                skeleton: badSkeleton,
                stageID: stageID,
                gripStyle: .overlap
            )
            #expect(!badEval.isAllPassing, "Stage \(stageID) 應攔截初學者 NG 姿勢")
            #expect(badEval.checkpoints.contains(where: { $0.status != .perfect }))

            let almostSkeleton = PostureEvaluator.presetSkeleton(for: stageID, mode: .almostThere)
            let almostEval = PostureEvaluator.evaluate(
                skeleton: almostSkeleton,
                stageID: stageID,
                gripStyle: .overlap
            )
            #expect(almostEval.overallAccuracy > badEval.overallAccuracy, "Stage \(stageID) 微調姿勢精準度應高於 NG 姿勢")

            let idealSkeleton = PostureEvaluator.presetSkeleton(for: stageID, mode: .idealPro)
            let idealEval = PostureEvaluator.evaluate(
                skeleton: idealSkeleton,
                stageID: stageID,
                gripStyle: .overlap
            )
            #expect(idealEval.isAllPassing, "Stage \(stageID) 應通過黃金標準姿勢")
            #expect(idealEval.overallAccuracy >= 86.0)
            #expect(idealEval.checkpoints.count == 3)
        }
    }

    @Test("三大握桿流派：重疊式、互鎖式、十指式皆通過理想 V 字角度並攔截錯誤角度")
    func gripStylesValidation() async throws {
        for style in GripStyle.allCases {
            let idealSkeleton = PostureEvaluator.presetSkeleton(for: .grip, mode: .idealPro)
            let eval = PostureEvaluator.evaluate(
                skeleton: idealSkeleton,
                stageID: .grip,
                gripStyle: style
            )
            #expect(eval.isAllPassing)

            var extremeWeakGrip = idealSkeleton
            extremeWeakGrip.detectedGripVAngle = -12.0
            extremeWeakGrip.handConnectionScore = 0.35
            let badEval = PostureEvaluator.evaluate(
                skeleton: extremeWeakGrip,
                stageID: .grip,
                gripStyle: style
            )
            #expect(badEval.checkpoints.contains(where: { $0.status == .needsCorrection }))
        }
    }

    @Test("幾何角度計算與零向量防禦保護")
    func geometricAngleCalculationAndZeroVectorSafety() async throws {
        // Right angle (90 degrees)
        let rightAngle = PostureEvaluator.threePointAngle(
            a: CGPoint(x: 0, y: 1),
            b: CGPoint(x: 0, y: 0),
            c: CGPoint(x: 1, y: 0)
        )
        #expect(abs(rightAngle - 90.0) < 0.01)

        // Straight line (180 degrees)
        let straightAngle = PostureEvaluator.threePointAngle(
            a: CGPoint(x: 0, y: 0),
            b: CGPoint(x: 0.5, y: 0),
            c: CGPoint(x: 1.0, y: 0)
        )
        #expect(abs(straightAngle - 180.0) < 0.01)

        // Coincident points (zero vector safety -> returns 180 without NaN)
        let degenerate = PostureEvaluator.threePointAngle(
            a: CGPoint(x: 0.5, y: 0.5),
            b: CGPoint(x: 0.5, y: 0.5),
            c: CGPoint(x: 0.5, y: 0.5)
        )
        #expect(!degenerate.isNaN)
        #expect(degenerate == 180.0)
    }

    @Test("空骨架防禦測試：即使未偵測到任何關節點也不崩潰或產生 NaN")
    func emptySkeletonResilience() async throws {
        let empty = PoseSkeleton(joints: [:], confidences: [:])
        for stageID in GolfStageID.allCases {
            let result = PostureEvaluator.evaluate(
                skeleton: empty,
                stageID: stageID,
                gripStyle: .overlap
            )
            #expect(!result.overallAccuracy.isNaN)
            #expect(result.checkpoints.count == 3)
        }
    }

    @Test("玩家經驗值升級與稱號晉升邏輯")
    func playerProfileLevelAndRankProgression() async throws {
        let profile = PlayerProfile(playerName: "測試球員", totalXP: 0)
        #expect(profile.level == 1)
        #expect(profile.rankTitle.contains("初心者"))

        profile.totalXP = 250
        #expect(profile.level == 2)
        #expect(profile.xpToNextLevel == 250)

        profile.totalXP = 1050
        #expect(profile.level == 5)
        #expect(profile.rankTitle.contains("大師"))
    }
}
