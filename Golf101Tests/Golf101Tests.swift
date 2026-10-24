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
            #expect(!result.isAllPassing, "關卡 \(stageID) 不應用預設關節位置把空骨架判成通過")
            #expect(result.checkpoints.allSatisfy { $0.status == .needsCorrection })
        }
    }

    @Test("玩家經驗值升級、登入簡介與練習次數通關徽章解鎖邏輯")
    func playerProfileLevelBadgeAndLoginProgression() async throws {
        let profile = PlayerProfile(
            playerName: "Mike Chen",
            playerBio: "目標三個月破百",
            avatarSymbol: "trophy.fill",
            hasCompletedOnboarding: true,
            totalPracticeSessions: 0,
            totalXP: 0
        )
        #expect(profile.level == 1)
        #expect(profile.rankTitle.contains("初心者"))
        #expect(PracticeBadge.highestUnlocked(totalSessions: profile.totalPracticeSessions, clearedStagesCount: 0) == nil)

        // Complete 1 session -> unlocks First Tee Rookie badge
        profile.totalPracticeSessions = 1
        profile.totalXP = 250
        #expect(profile.level == 2)
        #expect(PracticeBadge.highestUnlocked(totalSessions: profile.totalPracticeSessions, clearedStagesCount: 1)?.id == "badge_first_tee")

        // Complete 5 sessions -> unlocks Fairway Breaker Gold badge
        profile.totalPracticeSessions = 5
        #expect(PracticeBadge.highestUnlocked(totalSessions: profile.totalPracticeSessions, clearedStagesCount: 3)?.id == "badge_fairway_breaker")

        // Complete 20 sessions -> unlocks Grand Slam Legend badge
        profile.totalPracticeSessions = 20
        profile.totalXP = 1050
        #expect(profile.level == 5)
        #expect(profile.rankTitle.contains("大師"))
        #expect(PracticeBadge.highestUnlocked(totalSessions: profile.totalPracticeSessions, clearedStagesCount: 5)?.id == "badge_grand_slam")
        #expect(PracticeBadge.nextTargetBadge(totalSessions: profile.totalPracticeSessions, clearedStagesCount: 5) == nil)

        // Blank nickname & bio fallback sanitization
        profile.applyLoginProfile(name: "   \n ", bio: "   ", avatar: "  ")
        #expect(profile.playerName == PlayerProfile.defaultPlayerName)
        #expect(profile.playerBio == PlayerProfile.defaultPlayerBio)
        #expect(profile.avatarSymbol == "figure.golf")

        // Negative XP & negative session defensive clamping
        profile.totalXP = -120
        #expect(profile.level == 1)
        #expect(profile.currentLevelProgress >= 0.0)
        #expect(PracticeBadge.allBadges[0].progress(totalSessions: -3, clearedStagesCount: 0) == 0.0)
        #expect(PracticeBadge.allBadges[0].progressLabel(totalSessions: -3, clearedStagesCount: 0) == "0 / 1 次練習")
    }

    @Test("低信心度關節點過濾測試：信心度低於 0.15 的關節應被安全攔截")
    func lowConfidenceJointFiltering() async throws {
        var lowConfSkeleton = PostureEvaluator.presetSkeleton(for: .setup, mode: .idealPro)
        lowConfSkeleton.confidences[.leftAnkle] = 0.05
        lowConfSkeleton.confidences[.rightAnkle] = 0.08
        #expect(lowConfSkeleton.point(for: .leftAnkle) == nil)
        let eval = PostureEvaluator.evaluate(skeleton: lowConfSkeleton, stageID: .setup, gripStyle: .overlap)
        #expect(!eval.isAllPassing)
        #expect(eval.checkpoints.allSatisfy { $0.status == .needsCorrection })
    }

    @Test("語音指令解析測試：支援下一步、再說一次、重來、語音指令與雜訊過濾")
    func speechCommandParsingValidation() async throws {
        #expect(SpeechCommand.parse("請進入下一步") == .next)
        #expect(SpeechCommand.parse("完成 這一步") == .next)
        #expect(SpeechCommand.parse("教練再說一次") == .repeatTip)
        #expect(SpeechCommand.parse("重複提示") == .repeatTip)
        #expect(SpeechCommand.parse("重新開始練習") == .restartStep)
        #expect(SpeechCommand.parse("語音指令有哪些") == .help)
        #expect(SpeechCommand.parse("   　\n  ") == nil)
        #expect(SpeechCommand.parse("今天天氣真好") == nil)
    }

    @Test("練習進步軌跡紀錄：分解動作分數編解碼與最低分強化建議判定")
    func practiceHistoryRecordAndFocusMovementValidation() async throws {
        let scores: [String: Double] = [
            "setup_stance": 0.96,
            "setup_spine": 0.87,
            "setup_knee": 0.92
        ]
        let record = PracticeHistoryRecord(
            stageRawValue: GolfStageID.setup.rawValue,
            accuracy: 91.6,
            stars: 2,
            quizPassed: true,
            checkpointScores: scores
        )
        #expect(record.stageID == .setup)
        #expect(abs((record.checkpointScores["setup_spine"] ?? 0) - 0.87) < 0.0001)

        let lowest = PracticeHistoryRecord.lowestCheckpoint(in: record.checkpointScores)
        #expect(lowest?.id == "setup_spine")
        #expect(lowest?.title == "髖部前傾")
        #expect(abs((lowest?.scorePercent ?? 0) - 87.0) < 0.01)

        for stageID in GolfStageID.allCases {
            let orderedIDs = PracticeHistoryRecord.orderedCheckpointIDs(for: stageID)
            #expect(orderedIDs.count == 3)
        }
    }
}
