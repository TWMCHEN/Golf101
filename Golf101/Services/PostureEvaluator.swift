//
//  PostureEvaluator.swift
//  Golf101
//
//  Created by Golf101 AI Coach on 2026/10/23.
//

import Foundation
import CoreGraphics

enum SimulationPresetMode: String, CaseIterable, Identifiable {
    case beginnerMistake = "NG 常見錯誤"
    case almostThere = "微調練習中"
    case idealPro = "標準黃金姿勢"

    var id: String { rawValue }
}

struct PostureEvaluator {

    // MARK: - Main Evaluation Entry Point

    static func evaluate(
        skeleton: PoseSkeleton,
        stageID: GolfStageID,
        gripStyle: GripStyle
    ) -> StageEvaluationSummary {
        let checkpoints: [CheckpointResult]
        switch stageID {
        case .setup:
            checkpoints = evaluateSetup(skeleton: skeleton)
        case .grip:
            checkpoints = evaluateGrip(skeleton: skeleton, gripStyle: gripStyle)
        case .backswing:
            checkpoints = evaluateBackswing(skeleton: skeleton)
        case .impact:
            checkpoints = evaluateImpact(skeleton: skeleton)
        case .finish:
            checkpoints = evaluateFinish(skeleton: skeleton)
        }

        let avgProgress = checkpoints.map(\.progress).reduce(0, +) / Double(max(1, checkpoints.count))
        let overallAccuracy = min(100.0, max(0.0, avgProgress * 100.0))
        let isAllPassing = checkpoints.allSatisfy { $0.status == .perfect } || overallAccuracy >= 86.0

        let primaryTip: String
        if let worst = checkpoints.first(where: { $0.status == .needsCorrection }) {
            primaryTip = worst.correctionTip
        } else if let almost = checkpoints.first(where: { $0.status == .almost }) {
            primaryTip = almost.correctionTip
        } else {
            primaryTip = "太棒了！姿勢非常標準，請保持穩定直到進度圈集滿！"
        }

        return StageEvaluationSummary(
            stageID: stageID,
            checkpoints: checkpoints,
            overallAccuracy: overallAccuracy,
            primaryCoachTip: primaryTip,
            isAllPassing: isAllPassing
        )
    }

    // MARK: - Stage 1: Setup & Posture

    private static func evaluateSetup(skeleton: PoseSkeleton) -> [CheckpointResult] {
        let lShoulder = skeleton.joints[.leftShoulder] ?? CGPoint(x: 0.40, y: 0.30)
        let rShoulder = skeleton.joints[.rightShoulder] ?? CGPoint(x: 0.60, y: 0.30)
        let lAnkle = skeleton.joints[.leftAnkle] ?? CGPoint(x: 0.38, y: 0.84)
        let rAnkle = skeleton.joints[.rightAnkle] ?? CGPoint(x: 0.62, y: 0.84)
        let neck = skeleton.joints[.neck] ?? CGPoint(x: 0.50, y: 0.25)
        let root = skeleton.joints[.root] ?? CGPoint(x: 0.50, y: 0.54)
        let lHip = skeleton.joints[.leftHip] ?? CGPoint(x: 0.44, y: 0.54)
        let lKnee = skeleton.joints[.leftKnee] ?? CGPoint(x: 0.41, y: 0.70)
        let rHip = skeleton.joints[.rightHip] ?? CGPoint(x: 0.56, y: 0.54)
        let rKnee = skeleton.joints[.rightKnee] ?? CGPoint(x: 0.59, y: 0.70)

        // 1. Stance Width Ratio (ankle span vs shoulder span)
        let shoulderWidth = max(0.06, abs(rShoulder.x - lShoulder.x))
        let ankleWidth = abs(rAnkle.x - lAnkle.x)
        let stanceRatio = Double(ankleWidth / shoulderWidth)
        let stanceCheck = buildRangeCheckpoint(
            id: "setup_stance",
            title: "雙腳站幅寬度",
            value: stanceRatio,
            idealRange: 1.02...1.36,
            toleranceRange: 0.85...1.55,
            valueFormatter: { String(format: "%.2fx 肩寬", $0) },
            targetText: "1.0x ~ 1.35x 肩寬",
            lowTip: "雙腳站太窄囉！請把雙腳張開至與肩同寬，底盤才會穩固。",
            highTip: "雙腳張太開會限制髖部轉動！請稍微把腳往內收一點。",
            goodTip: "雙腳與肩同寬，底盤非常穩固！",
            joints: [.leftAnkle, .rightAnkle, .leftShoulder, .rightShoulder]
        )

        // 2. Spine Forward Tilt (computed from neck-to-root angle + hip hinge)
        let dxSpine = abs(Double(neck.x - root.x))
        let dySpine = max(0.05, Double(root.y - neck.y))
        let rawTiltDeg = atan2(dxSpine, dySpine) * 180.0 / .pi
        // Combine front/side cue so either side-view tilt or front-view hip-hinge compression works intuitively
        let torsoCompressionTilt = max(12.0, min(55.0, (0.29 - dySpine) * 220.0 + 34.0))
        let effectiveSpineTilt = rawTiltDeg > 12.0 ? rawTiltDeg : torsoCompressionTilt

        let spineCheck = buildRangeCheckpoint(
            id: "setup_spine",
            title: "脊椎髖部前傾角",
            value: effectiveSpineTilt,
            idealRange: 29.0...40.0,
            toleranceRange: 22.0...47.0,
            valueFormatter: { String(format: "%.0f°", $0) },
            targetText: "30° ~ 40°",
            lowTip: "站得太直像木頭人囉！請從髖關節（大腿根部）保持背部挺直向前微傾。",
            highTip: "過度彎腰駝背了！請抬起胸口，不要低頭拱背。",
            goodTip: "脊椎前傾角度完美，上半身轉動空間充足！",
            joints: [.neck, .root, .leftHip, .rightHip]
        )

        // 3. Knee Flex Angle
        let leftKneeAngle = threePointAngle(a: lHip, b: lKnee, c: lAnkle)
        let rightKneeAngle = threePointAngle(a: rHip, b: rKnee, c: rAnkle)
        let avgKneeAngle = (leftKneeAngle + rightKneeAngle) / 2.0

        let kneeCheck = buildRangeCheckpoint(
            id: "setup_knee",
            title: "膝蓋微彎彈性角",
            value: avgKneeAngle,
            idealRange: 152.0...171.0,
            toleranceRange: 138.0...177.0,
            valueFormatter: { String(format: "%.0f°", $0) },
            targetText: "152° ~ 170°",
            lowTip: "膝蓋蹲太低變成「坐馬桶姿勢」啦！稍微站高一點，保持微彎彈性即可。",
            highTip: "膝蓋鎖得太直囉！請讓雙膝微微彎曲放鬆，像準備接球一樣。",
            goodTip: "雙膝彈性極佳，重心完美踩在足弓！",
            joints: [.leftKnee, .rightKnee]
        )

        return [stanceCheck, spineCheck, kneeCheck]
    }

    // MARK: - Stage 2: Grip Mastery

    private static func evaluateGrip(skeleton: PoseSkeleton, gripStyle: GripStyle) -> [CheckpointResult] {
        let lShoulder = skeleton.joints[.leftShoulder] ?? CGPoint(x: 0.39, y: 0.30)
        let rShoulder = skeleton.joints[.rightShoulder] ?? CGPoint(x: 0.61, y: 0.31)
        let lWrist = skeleton.joints[.leftWrist] ?? CGPoint(x: 0.48, y: 0.52)
        let rWrist = skeleton.joints[.rightWrist] ?? CGPoint(x: 0.51, y: 0.53)
        let neck = skeleton.joints[.neck] ?? CGPoint(x: 0.50, y: 0.25)

        // 1. Hands Connection (Wrist proximity + handConnectionScore)
        let shoulderWidth = max(0.08, hypot(rShoulder.x - lShoulder.x, rShoulder.y - lShoulder.y))
        let wristDist = hypot(rWrist.x - lWrist.x, rWrist.y - lWrist.y)
        let geometricCloseness = max(0.0, min(1.0, 1.0 - Double(wristDist / shoulderWidth) * 1.15))
        let connectionPercent = ((geometricCloseness * 0.6) + (skeleton.handConnectionScore * 0.4)) * 100.0

        let connectionCheck = buildRangeCheckpoint(
            id: "grip_connection",
            title: "雙手緊密一體度 (\(gripStyle.shortName))",
            value: connectionPercent,
            idealRange: 82.0...100.0,
            toleranceRange: 68.0...100.0,
            valueFormatter: { String(format: "%.0f%%", $0) },
            targetText: "≥ 82% 緊密貼合",
            lowTip: "雙手握得太分開了！請將右手小指與左手食指靠攏（\(gripStyle.shortName)），讓雙手像一體運作。",
            highTip: "雙手緊密連接良好！",
            goodTip: "雙手緊密貼合，釋放球桿不會打架！",
            joints: [.leftWrist, .rightWrist]
        )

        // 2. V-Groove Alignment toward trail shoulder
        let vAngle = skeleton.detectedGripVAngle
        let idealV = gripStyle.idealVAngleRange
        let vCheck = buildRangeCheckpoint(
            id: "grip_v_angle",
            title: "虎口 V 字指向角度",
            value: vAngle,
            idealRange: idealV,
            toleranceRange: (idealV.lowerBound - 8.0)...(idealV.upperBound + 9.0),
            valueFormatter: { String(format: "右偏 %.0f°", $0) },
            targetText: "右偏 \(Int(idealV.lowerBound))°~\(Int(idealV.upperBound))° (指向右肩)",
            lowTip: "虎口太偏向左肩（弱勢握桿），擊球時桿面容易打開打出右曲球（Slice）！請把左手向順時針微轉露出兩顆指節。",
            highTip: "虎口轉過頭指向身體右側外（過度強勢），容易打出急左勾球（Hook）！請稍微回正。",
            goodTip: "虎口 V 字精準指向右肩與下巴之間！",
            joints: [.leftWrist, .rightWrist, .rightShoulder]
        )

        // 3. Setup Inverted Triangle (Hands centered beneath chin/neck)
        let handsCenter = CGPoint(x: (lWrist.x + rWrist.x) / 2.0, y: (lWrist.y + rWrist.y) / 2.0)
        let horizontalOffset = abs(Double(handsCenter.x - neck.x))
        let verticalDrop = Double(handsCenter.y - neck.y)
        let triangleScore = max(0.0, min(100.0, 100.0 - (horizontalOffset * 260.0) - max(0.0, (0.20 - verticalDrop) * 220.0)))

        let triangleCheck = buildRangeCheckpoint(
            id: "grip_triangle",
            title: "雙肩與雙手倒三角形",
            value: triangleScore,
            idealRange: 82.0...100.0,
            toleranceRange: 66.0...100.0,
            valueFormatter: { String(format: "%.0f 分", $0) },
            targetText: "≥ 82 分 (自然下垂置中)",
            lowTip: "雙手位置偏移或聳肩太緊繃！請雙肩放鬆下沉，讓雙手自然懸垂在下巴正下方。",
            highTip: "倒三角結構非常穩定！",
            goodTip: "雙臂與雙肩形成完美倒三角形！",
            joints: [.leftShoulder, .rightShoulder, .leftWrist, .rightWrist]
        )

        return [connectionCheck, vCheck, triangleCheck]
    }

    // MARK: - Stage 3: Backswing & Coil

    private static func evaluateBackswing(skeleton: PoseSkeleton) -> [CheckpointResult] {
        let lShoulder = skeleton.joints[.leftShoulder] ?? CGPoint(x: 0.48, y: 0.31)
        let rShoulder = skeleton.joints[.rightShoulder] ?? CGPoint(x: 0.62, y: 0.28)
        let lElbow = skeleton.joints[.leftElbow] ?? CGPoint(x: 0.56, y: 0.26)
        let lWrist = skeleton.joints[.leftWrist] ?? CGPoint(x: 0.65, y: 0.20)
        let rHip = skeleton.joints[.rightHip] ?? CGPoint(x: 0.57, y: 0.54)
        let rAnkle = skeleton.joints[.rightAnkle] ?? CGPoint(x: 0.61, y: 0.84)

        // 1. Lead Arm Extension (no chicken wing / bent left arm)
        let leadArmDeg = threePointAngle(a: lShoulder, b: lElbow, c: lWrist)
        let armCheck = buildRangeCheckpoint(
            id: "backswing_arm",
            title: "前導臂 (左手) 延伸度",
            value: leadArmDeg,
            idealRange: 154.0...180.0,
            toleranceRange: 136.0...180.0,
            valueFormatter: { String(format: "%.0f°", $0) },
            targetText: "155° ~ 180° (延伸不塌陷)",
            lowTip: "左手肘彎曲塌陷囉！不要只用手把球桿折起來舉高，請靠轉動肩膀把左手臂順勢撐寬。",
            highTip: "左手臂延伸幅度極佳！",
            goodTip: "左手臂保持漂亮延伸，揮桿圓弧超寬廣！",
            joints: [.leftShoulder, .leftElbow, .leftWrist]
        )

        // 2. Top of Backswing Hand Height & Shoulder Turn
        // On backswing top, wrists should rise near/above shoulder height and move to trail side
        let wristHeightGain = Double(rShoulder.y - lWrist.y) // positive when wrist is higher than shoulder
        let wristTrailShift = Double(lWrist.x - lShoulder.x)
        let coilDegrees = max(35.0, min(105.0, 72.0 + (wristHeightGain * 140.0) + (wristTrailShift * 85.0)))

        let coilCheck = buildRangeCheckpoint(
            id: "backswing_coil",
            title: "轉肩蓄力與上桿高度",
            value: coilDegrees,
            idealRange: 80.0...100.0,
            toleranceRange: 64.0...105.0,
            valueFormatter: { String(format: "轉肩 %.0f°", $0) },
            targetText: "轉肩 80° ~ 95°",
            lowTip: "上桿轉肩不足、雙手位置太低！請將左肩轉向下巴下方，雙手順勢舉高至右耳斜上方。",
            highTip: "上桿過度跨過頭頂（Over-swing）容易失控，稍微精簡一點更穩定！",
            goodTip: "上桿頂點位置與轉肩扭力完美！",
            joints: [.leftShoulder, .rightShoulder, .leftWrist]
        )

        // 3. Anti-Sway Lower Body Stability (Right hip stays inside/over right ankle)
        let hipSwayOffset = Double(rHip.x - rAnkle.x) // positive means hip swayed outside right ankle
        let stabilityScore = max(0.0, min(100.0, 95.0 - max(0.0, hipSwayOffset) * 420.0))

        let swayCheck = buildRangeCheckpoint(
            id: "backswing_sway",
            title: "下盤軸心防橫移 (Anti-Sway)",
            value: stabilityScore,
            idealRange: 82.0...100.0,
            toleranceRange: 65.0...100.0,
            valueFormatter: { String(format: "%.0f%% 穩定", $0) },
            targetText: "≥ 82% 踩穩右腳內側",
            lowTip: "發生「身體右移搖晃 (Sway)」啦！右臀已經滑出右腳踝外側，請把重心踩在右腳足弓內側原地旋轉。",
            highTip: "下盤軸心如岩石般穩固！",
            goodTip: "重心穩穩鎖在右腳內側，完全沒有橫移搖晃！",
            joints: [.rightHip, .rightKnee, .rightAnkle]
        )

        return [armCheck, coilCheck, swayCheck]
    }

    // MARK: - Stage 4: Downswing & Impact

    private static func evaluateImpact(skeleton: PoseSkeleton) -> [CheckpointResult] {
        let nose = skeleton.joints[.nose] ?? CGPoint(x: 0.50, y: 0.19)
        let root = skeleton.joints[.root] ?? CGPoint(x: 0.43, y: 0.53)
        let lAnkle = skeleton.joints[.leftAnkle] ?? CGPoint(x: 0.39, y: 0.84)
        let rAnkle = skeleton.joints[.rightAnkle] ?? CGPoint(x: 0.61, y: 0.84)
        let lWrist = skeleton.joints[.leftWrist] ?? CGPoint(x: 0.44, y: 0.52)

        // 1. Weight Shift to Lead Side (Root closer to leftAnkle than rightAnkle)
        let span = max(0.10, Double(rAnkle.x - lAnkle.x))
        let distFromRight = Double(rAnkle.x - root.x)
        let leadWeightPercent = max(25.0, min(95.0, (distFromRight / span) * 100.0))

        let weightCheck = buildRangeCheckpoint(
            id: "impact_weight",
            title: "重心轉移至左腳比例",
            value: leadWeightPercent,
            idealRange: 68.0...88.0,
            toleranceRange: 55.0...94.0,
            valueFormatter: { String(format: "%.0f%% 左腳", $0) },
            targetText: "70% ~ 85% 在左腳",
            lowTip: "重心還留在後腳（右腳）！這會導致「撈球」打厚或剃頭，請先把左臀往目標方向微推。",
            highTip: "下盤太過度前衝囉，保持左腿穩固支撐即可！",
            goodTip: "下半身完美領先，重心紮實踩在左腳！",
            joints: [.root, .leftHip, .leftAnkle]
        )

        // 2. Forward Shaft Lean (Hands ahead of center ball position ~0.50)
        let ballX = Double((lAnkle.x + rAnkle.x) / 2.0)
        let handsLead = (ballX - Double(lWrist.x)) * 120.0 // positive when hands are toward target (left on screen)
        let leanCheck = buildRangeCheckpoint(
            id: "impact_lean",
            title: "雙手領先球位 (桿身前傾)",
            value: handsLead,
            idealRange: 4.0...15.0,
            toleranceRange: 0.0...20.0,
            valueFormatter: { String(format: "領先 %.1f°", $0) },
            targetText: "領先 4° ~ 14°",
            lowTip: "雙手落後於球（提早釋放拋竿 Casting）！擊球瞬間請讓左手背微領先球位，向下擠壓擊球。",
            highTip: "雙手推太前面囉，小心桿面過度關閉！",
            goodTip: "完美延遲釋放與桿身前傾，擊球超紮實！",
            joints: [.leftWrist, .rightWrist, .leftElbow]
        )

        // 3. Head Stay Behind the Ball
        let headOffsetBehindBall = (Double(nose.x) - ballX) * 100.0 // >= -2 means head stays centered/slightly behind ball
        let headStability = max(0.0, min(100.0, 92.0 - max(0.0, -headOffsetBehindBall - 1.5) * 9.5))

        let headCheck = buildRangeCheckpoint(
            id: "impact_head",
            title: "頭部穩定留於球後",
            value: headStability,
            idealRange: 82.0...100.0,
            toleranceRange: 68.0...100.0,
            valueFormatter: { String(format: "%.0f 分", $0) },
            targetText: "≥ 82 分 (頭不前衝)",
            lowTip: "擊球時頭部跟著往前衝出去啦！請讓重心移往左腳的同時，鼻尖與視線穩定留在球的後方。",
            highTip: "頭部軸心極度穩定！",
            goodTip: "下盤前移、頭部留後，這就是職業選手的黃金軸心！",
            joints: [.nose, .neck]
        )

        return [weightCheck, leanCheck, headCheck]
    }

    // MARK: - Stage 5: Follow-through & Finish

    private static func evaluateFinish(skeleton: PoseSkeleton) -> [CheckpointResult] {
        let neck = skeleton.joints[.neck] ?? CGPoint(x: 0.40, y: 0.24)
        let root = skeleton.joints[.root] ?? CGPoint(x: 0.40, y: 0.52)
        let lAnkle = skeleton.joints[.leftAnkle] ?? CGPoint(x: 0.40, y: 0.84)
        let lShoulder = skeleton.joints[.leftShoulder] ?? CGPoint(x: 0.37, y: 0.29)
        let lWrist = skeleton.joints[.leftWrist] ?? CGPoint(x: 0.33, y: 0.21)
        let rKnee = skeleton.joints[.rightKnee] ?? CGPoint(x: 0.45, y: 0.69)
        let lKnee = skeleton.joints[.leftKnee] ?? CGPoint(x: 0.39, y: 0.69)

        // 1. Stacked Balance Over Lead Foot
        let stackDeviation = abs(Double(root.x - lAnkle.x)) + abs(Double(neck.x - lAnkle.x)) * 0.8
        let balanceScore = max(0.0, min(100.0, 100.0 - stackDeviation * 260.0))

        let balanceCheck = buildRangeCheckpoint(
            id: "finish_balance",
            title: "左腳獨立支撐平衡度",
            value: balanceScore,
            idealRange: 82.0...100.0,
            toleranceRange: 65.0...100.0,
            valueFormatter: { String(format: "%.0f%% 穩定", $0) },
            targetText: "≥ 82% 重心在左腳",
            lowTip: "收桿時身體重心往後倒囉！請把肚臍與胸口完全轉向目標，穩穩站在左腳上。",
            highTip: "收桿平衡感滿分！",
            goodTip: "金雞獨立般穩定！重心 90% 完美落在左腳！",
            joints: [.neck, .root, .leftAnkle]
        )

        // 2. High Finish Hands (Hands near/above lead shoulder & ear)
        let handHeightScore = max(0.0, min(100.0, 88.0 + Double(lShoulder.y - lWrist.y) * 180.0))
        let finishHandsCheck = buildRangeCheckpoint(
            id: "finish_hands",
            title: "收桿雙手高度位置",
            value: handHeightScore,
            idealRange: 82.0...100.0,
            toleranceRange: 66.0...100.0,
            valueFormatter: { String(format: "%.0f 分", $0) },
            targetText: "收於左耳斜後方",
            lowTip: "擊球後雙手急煞車停在半空中！請順勢送桿到底，讓雙手自然收在左耳與左肩後方。",
            highTip: "收桿高度優雅流暢！",
            goodTip: "雙手完整收在左肩上方，揮桿釋放毫無保留！",
            joints: [.leftWrist, .rightWrist, .leftShoulder]
        )

        // 3. Trail Knee & Foot Release (Right knee kisses left knee)
        let kneeProximity = abs(Double(rKnee.x - lKnee.x))
        let releaseScore = max(0.0, min(100.0, 100.0 - max(0.0, kneeProximity - 0.05) * 320.0))

        let kneeReleaseCheck = buildRangeCheckpoint(
            id: "finish_knee",
            title: "右膝靠攏與右腳尖點地",
            value: releaseScore,
            idealRange: 80.0...100.0,
            toleranceRange: 62.0...100.0,
            valueFormatter: { String(format: "%.0f%% 釋放", $0) },
            targetText: "右膝靠攏左膝",
            lowTip: "右腳掌還死死黏在地上！請讓右腳跟自然抬起、右膝往左膝靠攏，身體才轉得過去。",
            highTip: "下半身旋轉釋放超到位！",
            goodTip: "右膝自然靠攏左膝、右腳尖優雅點地，標準職業收桿！",
            joints: [.rightKnee, .leftKnee, .rightAnkle]
        )

        return [balanceCheck, finishHandsCheck, kneeReleaseCheck]
    }

    // MARK: - Preset Skeletons for Interactive Simulator & Mistake Comparison

    static func presetSkeleton(for stageID: GolfStageID, mode: SimulationPresetMode) -> PoseSkeleton {
        switch (stageID, mode) {

        // STAGE 1: SETUP
        case (.setup, .beginnerMistake):
            // Narrow feet, overly squatted knees ("sitting on toilet"), hunched neck
            return PoseSkeleton(
                joints: [
                    .nose: CGPoint(x: 0.50, y: 0.28),
                    .neck: CGPoint(x: 0.50, y: 0.34),
                    .leftShoulder: CGPoint(x: 0.43, y: 0.37),
                    .rightShoulder: CGPoint(x: 0.57, y: 0.37),
                    .leftElbow: CGPoint(x: 0.45, y: 0.49),
                    .rightElbow: CGPoint(x: 0.55, y: 0.49),
                    .leftWrist: CGPoint(x: 0.49, y: 0.57),
                    .rightWrist: CGPoint(x: 0.51, y: 0.57),
                    .root: CGPoint(x: 0.50, y: 0.55),
                    .leftHip: CGPoint(x: 0.47, y: 0.55),
                    .rightHip: CGPoint(x: 0.53, y: 0.55),
                    .leftKnee: CGPoint(x: 0.41, y: 0.71),
                    .rightKnee: CGPoint(x: 0.59, y: 0.71),
                    .leftAnkle: CGPoint(x: 0.46, y: 0.84),
                    .rightAnkle: CGPoint(x: 0.54, y: 0.84)
                ],
                detectedGripVAngle: 20,
                handConnectionScore: 0.90
            )

        case (.setup, .almostThere):
            return PoseSkeleton(
                joints: [
                    .nose: CGPoint(x: 0.50, y: 0.21),
                    .neck: CGPoint(x: 0.50, y: 0.27),
                    .leftShoulder: CGPoint(x: 0.44, y: 0.31),
                    .rightShoulder: CGPoint(x: 0.56, y: 0.31),
                    .leftElbow: CGPoint(x: 0.45, y: 0.43),
                    .rightElbow: CGPoint(x: 0.55, y: 0.43),
                    .leftWrist: CGPoint(x: 0.49, y: 0.52),
                    .rightWrist: CGPoint(x: 0.51, y: 0.53),
                    .root: CGPoint(x: 0.50, y: 0.54),
                    .leftHip: CGPoint(x: 0.465, y: 0.54),
                    .rightHip: CGPoint(x: 0.535, y: 0.54),
                    .leftKnee: CGPoint(x: 0.42, y: 0.70),
                    .rightKnee: CGPoint(x: 0.58, y: 0.70),
                    .leftAnkle: CGPoint(x: 0.44, y: 0.84),
                    .rightAnkle: CGPoint(x: 0.56, y: 0.84)
                ],
                detectedGripVAngle: 20,
                handConnectionScore: 0.92
            )

        case (.setup, .idealPro):
            return PoseSkeleton(
                joints: [
                    .nose: CGPoint(x: 0.50, y: 0.19),
                    .neck: CGPoint(x: 0.50, y: 0.25),
                    .leftShoulder: CGPoint(x: 0.44, y: 0.29),
                    .rightShoulder: CGPoint(x: 0.56, y: 0.29),
                    .leftElbow: CGPoint(x: 0.45, y: 0.42),
                    .rightElbow: CGPoint(x: 0.55, y: 0.42),
                    .leftWrist: CGPoint(x: 0.49, y: 0.52),
                    .rightWrist: CGPoint(x: 0.51, y: 0.53),
                    .root: CGPoint(x: 0.50, y: 0.54),
                    .leftHip: CGPoint(x: 0.465, y: 0.54),
                    .rightHip: CGPoint(x: 0.535, y: 0.54),
                    .leftKnee: CGPoint(x: 0.425, y: 0.70),
                    .rightKnee: CGPoint(x: 0.575, y: 0.70),
                    .leftAnkle: CGPoint(x: 0.43, y: 0.84),
                    .rightAnkle: CGPoint(x: 0.57, y: 0.84)
                ],
                detectedGripVAngle: 21,
                handConnectionScore: 0.96
            )

        // STAGE 2: GRIP
        case (.grip, .beginnerMistake):
            // Hands split apart like a hockey stick, weak V angle (-5 deg)
            return PoseSkeleton(
                joints: [
                    .nose: CGPoint(x: 0.50, y: 0.19),
                    .neck: CGPoint(x: 0.50, y: 0.25),
                    .leftShoulder: CGPoint(x: 0.43, y: 0.29),
                    .rightShoulder: CGPoint(x: 0.57, y: 0.31),
                    .leftElbow: CGPoint(x: 0.42, y: 0.42),
                    .rightElbow: CGPoint(x: 0.58, y: 0.44),
                    .leftWrist: CGPoint(x: 0.43, y: 0.50),
                    .rightWrist: CGPoint(x: 0.57, y: 0.56),
                    .root: CGPoint(x: 0.50, y: 0.54),
                    .leftHip: CGPoint(x: 0.465, y: 0.54),
                    .rightHip: CGPoint(x: 0.535, y: 0.54),
                    .leftKnee: CGPoint(x: 0.445, y: 0.70),
                    .rightKnee: CGPoint(x: 0.555, y: 0.70),
                    .leftAnkle: CGPoint(x: 0.42, y: 0.84),
                    .rightAnkle: CGPoint(x: 0.58, y: 0.84)
                ],
                detectedGripVAngle: -4.0,
                handConnectionScore: 0.45
            )

        case (.grip, .almostThere):
            return PoseSkeleton(
                joints: [
                    .nose: CGPoint(x: 0.50, y: 0.19),
                    .neck: CGPoint(x: 0.50, y: 0.25),
                    .leftShoulder: CGPoint(x: 0.43, y: 0.29),
                    .rightShoulder: CGPoint(x: 0.57, y: 0.31),
                    .leftElbow: CGPoint(x: 0.45, y: 0.42),
                    .rightElbow: CGPoint(x: 0.55, y: 0.43),
                    .leftWrist: CGPoint(x: 0.47, y: 0.52),
                    .rightWrist: CGPoint(x: 0.53, y: 0.54),
                    .root: CGPoint(x: 0.50, y: 0.54),
                    .leftHip: CGPoint(x: 0.465, y: 0.54),
                    .rightHip: CGPoint(x: 0.535, y: 0.54),
                    .leftKnee: CGPoint(x: 0.445, y: 0.70),
                    .rightKnee: CGPoint(x: 0.555, y: 0.70),
                    .leftAnkle: CGPoint(x: 0.42, y: 0.84),
                    .rightAnkle: CGPoint(x: 0.58, y: 0.84)
                ],
                detectedGripVAngle: 10.0,
                handConnectionScore: 0.78
            )

        case (.grip, .idealPro):
            return PoseSkeleton(
                joints: [
                    .nose: CGPoint(x: 0.50, y: 0.19),
                    .neck: CGPoint(x: 0.50, y: 0.25),
                    .leftShoulder: CGPoint(x: 0.43, y: 0.29),
                    .rightShoulder: CGPoint(x: 0.57, y: 0.31),
                    .leftElbow: CGPoint(x: 0.46, y: 0.42),
                    .rightElbow: CGPoint(x: 0.54, y: 0.43),
                    .leftWrist: CGPoint(x: 0.49, y: 0.52),
                    .rightWrist: CGPoint(x: 0.51, y: 0.53),
                    .root: CGPoint(x: 0.50, y: 0.54),
                    .leftHip: CGPoint(x: 0.465, y: 0.54),
                    .rightHip: CGPoint(x: 0.535, y: 0.54),
                    .leftKnee: CGPoint(x: 0.445, y: 0.70),
                    .rightKnee: CGPoint(x: 0.555, y: 0.70),
                    .leftAnkle: CGPoint(x: 0.42, y: 0.84),
                    .rightAnkle: CGPoint(x: 0.58, y: 0.84)
                ],
                detectedGripVAngle: 21.0,
                handConnectionScore: 0.96
            )

        // STAGE 3: BACKSWING
        case (.backswing, .beginnerMistake):
            // Bent left arm ("chicken wing"), low hands, right hip swayed past right ankle
            return PoseSkeleton(
                joints: [
                    .nose: CGPoint(x: 0.53, y: 0.20),
                    .neck: CGPoint(x: 0.53, y: 0.26),
                    .leftShoulder: CGPoint(x: 0.46, y: 0.31),
                    .rightShoulder: CGPoint(x: 0.59, y: 0.30),
                    .leftElbow: CGPoint(x: 0.47, y: 0.42),
                    .rightElbow: CGPoint(x: 0.63, y: 0.40),
                    .leftWrist: CGPoint(x: 0.55, y: 0.35),
                    .rightWrist: CGPoint(x: 0.57, y: 0.36),
                    .root: CGPoint(x: 0.57, y: 0.54),
                    .leftHip: CGPoint(x: 0.52, y: 0.54),
                    .rightHip: CGPoint(x: 0.63, y: 0.54),
                    .leftKnee: CGPoint(x: 0.47, y: 0.70),
                    .rightKnee: CGPoint(x: 0.61, y: 0.70),
                    .leftAnkle: CGPoint(x: 0.43, y: 0.84),
                    .rightAnkle: CGPoint(x: 0.57, y: 0.84)
                ],
                detectedGripVAngle: 20,
                handConnectionScore: 0.90
            )

        case (.backswing, .almostThere):
            return PoseSkeleton(
                joints: [
                    .nose: CGPoint(x: 0.51, y: 0.19),
                    .neck: CGPoint(x: 0.51, y: 0.25),
                    .leftShoulder: CGPoint(x: 0.47, y: 0.31),
                    .rightShoulder: CGPoint(x: 0.58, y: 0.28),
                    .leftElbow: CGPoint(x: 0.55, y: 0.29),
                    .rightElbow: CGPoint(x: 0.63, y: 0.32),
                    .leftWrist: CGPoint(x: 0.62, y: 0.24),
                    .rightWrist: CGPoint(x: 0.64, y: 0.25),
                    .root: CGPoint(x: 0.52, y: 0.54),
                    .leftHip: CGPoint(x: 0.48, y: 0.54),
                    .rightHip: CGPoint(x: 0.56, y: 0.54),
                    .leftKnee: CGPoint(x: 0.46, y: 0.70),
                    .rightKnee: CGPoint(x: 0.56, y: 0.70),
                    .leftAnkle: CGPoint(x: 0.43, y: 0.84),
                    .rightAnkle: CGPoint(x: 0.57, y: 0.84)
                ],
                detectedGripVAngle: 20,
                handConnectionScore: 0.94
            )

        case (.backswing, .idealPro):
            // Extended left arm (168 deg), high hands over trail shoulder, right hip inside right ankle
            return PoseSkeleton(
                joints: [
                    .nose: CGPoint(x: 0.50, y: 0.19),
                    .neck: CGPoint(x: 0.50, y: 0.25),
                    .leftShoulder: CGPoint(x: 0.47, y: 0.31),
                    .rightShoulder: CGPoint(x: 0.58, y: 0.27),
                    .leftElbow: CGPoint(x: 0.56, y: 0.25),
                    .rightElbow: CGPoint(x: 0.63, y: 0.29),
                    .leftWrist: CGPoint(x: 0.65, y: 0.19),
                    .rightWrist: CGPoint(x: 0.67, y: 0.20),
                    .root: CGPoint(x: 0.51, y: 0.54),
                    .leftHip: CGPoint(x: 0.475, y: 0.54),
                    .rightHip: CGPoint(x: 0.545, y: 0.54),
                    .leftKnee: CGPoint(x: 0.455, y: 0.70),
                    .rightKnee: CGPoint(x: 0.555, y: 0.70),
                    .leftAnkle: CGPoint(x: 0.43, y: 0.84),
                    .rightAnkle: CGPoint(x: 0.57, y: 0.84)
                ],
                detectedGripVAngle: 21,
                handConnectionScore: 0.96
            )

        // STAGE 4: IMPACT
        case (.impact, .beginnerMistake):
            // Weight hanging back on right foot, hands behind ball (scooping), head lunging or falling back
            return PoseSkeleton(
                joints: [
                    .nose: CGPoint(x: 0.44, y: 0.20),
                    .neck: CGPoint(x: 0.48, y: 0.26),
                    .leftShoulder: CGPoint(x: 0.44, y: 0.30),
                    .rightShoulder: CGPoint(x: 0.57, y: 0.33),
                    .leftElbow: CGPoint(x: 0.48, y: 0.43),
                    .rightElbow: CGPoint(x: 0.57, y: 0.45),
                    .leftWrist: CGPoint(x: 0.54, y: 0.53),
                    .rightWrist: CGPoint(x: 0.56, y: 0.54),
                    .root: CGPoint(x: 0.54, y: 0.54),
                    .leftHip: CGPoint(x: 0.50, y: 0.54),
                    .rightHip: CGPoint(x: 0.57, y: 0.54),
                    .leftKnee: CGPoint(x: 0.46, y: 0.70),
                    .rightKnee: CGPoint(x: 0.57, y: 0.70),
                    .leftAnkle: CGPoint(x: 0.43, y: 0.84),
                    .rightAnkle: CGPoint(x: 0.57, y: 0.84)
                ],
                detectedGripVAngle: 20,
                handConnectionScore: 0.92
            )

        case (.impact, .almostThere):
            return PoseSkeleton(
                joints: [
                    .nose: CGPoint(x: 0.50, y: 0.19),
                    .neck: CGPoint(x: 0.49, y: 0.25),
                    .leftShoulder: CGPoint(x: 0.42, y: 0.29),
                    .rightShoulder: CGPoint(x: 0.55, y: 0.32),
                    .leftElbow: CGPoint(x: 0.44, y: 0.41),
                    .rightElbow: CGPoint(x: 0.52, y: 0.43),
                    .leftWrist: CGPoint(x: 0.48, y: 0.52),
                    .rightWrist: CGPoint(x: 0.50, y: 0.53),
                    .root: CGPoint(x: 0.47, y: 0.53),
                    .leftHip: CGPoint(x: 0.435, y: 0.52),
                    .rightHip: CGPoint(x: 0.505, y: 0.54),
                    .leftKnee: CGPoint(x: 0.43, y: 0.69),
                    .rightKnee: CGPoint(x: 0.535, y: 0.70),
                    .leftAnkle: CGPoint(x: 0.43, y: 0.84),
                    .rightAnkle: CGPoint(x: 0.57, y: 0.84)
                ],
                detectedGripVAngle: 20,
                handConnectionScore: 0.94
            )

        case (.impact, .idealPro):
            // Weight shifted onto lead foot, hands ahead of ball, head steady behind ball
            return PoseSkeleton(
                joints: [
                    .nose: CGPoint(x: 0.51, y: 0.19),
                    .neck: CGPoint(x: 0.49, y: 0.25),
                    .leftShoulder: CGPoint(x: 0.42, y: 0.28),
                    .rightShoulder: CGPoint(x: 0.55, y: 0.32),
                    .leftElbow: CGPoint(x: 0.42, y: 0.40),
                    .rightElbow: CGPoint(x: 0.50, y: 0.43),
                    .leftWrist: CGPoint(x: 0.43, y: 0.51),
                    .rightWrist: CGPoint(x: 0.45, y: 0.52),
                    .root: CGPoint(x: 0.46, y: 0.53),
                    .leftHip: CGPoint(x: 0.425, y: 0.52),
                    .rightHip: CGPoint(x: 0.495, y: 0.54),
                    .leftKnee: CGPoint(x: 0.425, y: 0.69),
                    .rightKnee: CGPoint(x: 0.52, y: 0.70),
                    .leftAnkle: CGPoint(x: 0.43, y: 0.84),
                    .rightAnkle: CGPoint(x: 0.57, y: 0.84)
                ],
                detectedGripVAngle: 21,
                handConnectionScore: 0.96
            )

        // STAGE 5: FINISH
        case (.finish, .beginnerMistake):
            // Falling backward onto trail foot, low cramped hands, wide knees
            return PoseSkeleton(
                joints: [
                    .nose: CGPoint(x: 0.54, y: 0.20),
                    .neck: CGPoint(x: 0.53, y: 0.26),
                    .leftShoulder: CGPoint(x: 0.46, y: 0.31),
                    .rightShoulder: CGPoint(x: 0.57, y: 0.32),
                    .leftElbow: CGPoint(x: 0.39, y: 0.39),
                    .rightElbow: CGPoint(x: 0.46, y: 0.41),
                    .leftWrist: CGPoint(x: 0.42, y: 0.35),
                    .rightWrist: CGPoint(x: 0.44, y: 0.36),
                    .root: CGPoint(x: 0.53, y: 0.54),
                    .leftHip: CGPoint(x: 0.49, y: 0.54),
                    .rightHip: CGPoint(x: 0.56, y: 0.54),
                    .leftKnee: CGPoint(x: 0.45, y: 0.70),
                    .rightKnee: CGPoint(x: 0.56, y: 0.70),
                    .leftAnkle: CGPoint(x: 0.43, y: 0.84),
                    .rightAnkle: CGPoint(x: 0.56, y: 0.84)
                ],
                detectedGripVAngle: 20,
                handConnectionScore: 0.90
            )

        case (.finish, .almostThere):
            return PoseSkeleton(
                joints: [
                    .nose: CGPoint(x: 0.45, y: 0.18),
                    .neck: CGPoint(x: 0.45, y: 0.24),
                    .leftShoulder: CGPoint(x: 0.40, y: 0.29),
                    .rightShoulder: CGPoint(x: 0.49, y: 0.29),
                    .leftElbow: CGPoint(x: 0.34, y: 0.26),
                    .rightElbow: CGPoint(x: 0.39, y: 0.27),
                    .leftWrist: CGPoint(x: 0.36, y: 0.23),
                    .rightWrist: CGPoint(x: 0.38, y: 0.24),
                    .root: CGPoint(x: 0.45, y: 0.52),
                    .leftHip: CGPoint(x: 0.42, y: 0.52),
                    .rightHip: CGPoint(x: 0.48, y: 0.52),
                    .leftKnee: CGPoint(x: 0.43, y: 0.69),
                    .rightKnee: CGPoint(x: 0.49, y: 0.70),
                    .leftAnkle: CGPoint(x: 0.43, y: 0.84),
                    .rightAnkle: CGPoint(x: 0.53, y: 0.82)
                ],
                detectedGripVAngle: 20,
                handConnectionScore: 0.94
            )

        case (.finish, .idealPro):
            // Stacked cleanly over leftAnkle (x=0.43), hands high behind left ear, right knee kissing left knee
            return PoseSkeleton(
                joints: [
                    .nose: CGPoint(x: 0.43, y: 0.17),
                    .neck: CGPoint(x: 0.43, y: 0.24),
                    .leftShoulder: CGPoint(x: 0.39, y: 0.29),
                    .rightShoulder: CGPoint(x: 0.47, y: 0.28),
                    .leftElbow: CGPoint(x: 0.33, y: 0.23),
                    .rightElbow: CGPoint(x: 0.38, y: 0.24),
                    .leftWrist: CGPoint(x: 0.35, y: 0.18),
                    .rightWrist: CGPoint(x: 0.37, y: 0.19),
                    .root: CGPoint(x: 0.43, y: 0.52),
                    .leftHip: CGPoint(x: 0.405, y: 0.52),
                    .rightHip: CGPoint(x: 0.455, y: 0.52),
                    .leftKnee: CGPoint(x: 0.42, y: 0.69),
                    .rightKnee: CGPoint(x: 0.455, y: 0.69),
                    .leftAnkle: CGPoint(x: 0.43, y: 0.84),
                    .rightAnkle: CGPoint(x: 0.51, y: 0.81)
                ],
                detectedGripVAngle: 21,
                handConnectionScore: 0.96
            )
        }
    }

    // MARK: - Math & Geometry Helpers

    static func threePointAngle(a: CGPoint, b: CGPoint, c: CGPoint) -> Double {
        let v1 = CGVector(dx: a.x - b.x, dy: a.y - b.y)
        let v2 = CGVector(dx: c.x - b.x, dy: c.y - b.y)
        let dot = v1.dx * v2.dx + v1.dy * v2.dy
        let mag1 = hypot(v1.dx, v1.dy)
        let mag2 = hypot(v2.dx, v2.dy)
        guard mag1 > 0.0001, mag2 > 0.0001 else { return 180.0 }
        let cosAngle = max(-1.0, min(1.0, Double(dot / (mag1 * mag2))))
        return acos(cosAngle) * 180.0 / .pi
    }

    private static func buildRangeCheckpoint(
        id: String,
        title: String,
        value: Double,
        idealRange: ClosedRange<Double>,
        toleranceRange: ClosedRange<Double>,
        valueFormatter: (Double) -> String,
        targetText: String,
        lowTip: String,
        highTip: String,
        goodTip: String,
        joints: [SkeletonJoint]
    ) -> CheckpointResult {
        let status: CheckStatus
        let progress: Double
        let tip: String

        if idealRange.contains(value) {
            status = .perfect
            let center = (idealRange.lowerBound + idealRange.upperBound) / 2.0
            let halfSpan = max(0.001, (idealRange.upperBound - idealRange.lowerBound) / 2.0)
            let distFromCenter = abs(value - center) / halfSpan
            progress = max(0.88, 1.0 - distFromCenter * 0.12)
            tip = goodTip
        } else if toleranceRange.contains(value) {
            status = .almost
            if value < idealRange.lowerBound {
                let span = max(0.001, idealRange.lowerBound - toleranceRange.lowerBound)
                progress = 0.55 + 0.32 * ((value - toleranceRange.lowerBound) / span)
                tip = lowTip
            } else {
                let span = max(0.001, toleranceRange.upperBound - idealRange.upperBound)
                progress = 0.55 + 0.32 * ((toleranceRange.upperBound - value) / span)
                tip = highTip
            }
        } else {
            status = .needsCorrection
            if value < toleranceRange.lowerBound {
                let deficit = toleranceRange.lowerBound - value
                let span = max(0.001, idealRange.upperBound - idealRange.lowerBound)
                progress = max(0.12, 0.50 - (deficit / (span * 2.0)) * 0.40)
                tip = lowTip
            } else {
                let excess = value - toleranceRange.upperBound
                let span = max(0.001, idealRange.upperBound - idealRange.lowerBound)
                progress = max(0.12, 0.50 - (excess / (span * 2.0)) * 0.40)
                tip = highTip
            }
        }

        return CheckpointResult(
            id: id,
            title: title,
            currentValueText: valueFormatter(value),
            targetValueText: targetText,
            progress: progress,
            status: status,
            correctionTip: tip,
            highlightedJoints: joints
        )
    }
}
