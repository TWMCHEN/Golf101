//
//  GolfGameModels.swift
//  Golf101
//
//  Created by Golf101 AI Coach on 2026/10/23.
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - Stage Identifier & Grip Types

enum GolfStageID: Int, CaseIterable, Codable, Identifiable {
    case setup = 1
    case grip = 2
    case backswing = 3
    case impact = 4
    case finish = 5

    var id: Int { rawValue }
}

enum GripStyle: String, CaseIterable, Codable, Identifiable {
    case overlap = "重疊握桿 (Overlap)"
    case interlock = "互鎖握桿 (Interlock)"
    case tenFinger = "十指握桿 (Ten-Finger)"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .overlap: return "重疊式"
        case .interlock: return "互鎖式"
        case .tenFinger: return "十指式"
        }
    }

    var recommendationTag: String {
        switch self {
        case .overlap: return "最常見標準握法"
        case .interlock: return "適合手型較小或初學者"
        case .tenFinger: return "適合力量較小或青少年"
        }
    }

    var detailDescription: String {
        switch self {
        case .overlap:
            return "右手小指輕疊在左手食指與中指縫隙上，雙手虎口 V 字皆指向右肩，能有效統一雙手釋放感。"
        case .interlock:
            return "右手小指與左手食指交叉互扣（Tiger Woods 與 Rory McIlroy 採用），雙手一體感最強、不易滑動。"
        case .tenFinger:
            return "十根手指皆接觸握把，左手大拇指包覆在右手掌生命線中，容易發力但需注意雙手不要分開。"
        }
    }

    /// Slightly different ideal V-groove angle ranges by grip style
    var idealVAngleRange: ClosedRange<Double> {
        switch self {
        case .overlap: return 14...28
        case .interlock: return 15...30
        case .tenFinger: return 12...26
        }
    }
}

// MARK: - Pose Joints & Skeleton Representation

nonisolated enum SkeletonJoint: String, CaseIterable, Hashable, Sendable {
    case nose
    case neck
    case leftShoulder
    case rightShoulder
    case leftElbow
    case rightElbow
    case leftWrist
    case rightWrist
    case root
    case leftHip
    case rightHip
    case leftKnee
    case rightKnee
    case leftAnkle
    case rightAnkle
    // Hand-specific landmarks for Grip Stage
    case leftThumbTip
    case leftIndexMCP
    case rightThumbTip
    case rightIndexMCP

    var displayName: String {
        switch self {
        case .nose: return "頭部"
        case .neck: return "頸部"
        case .leftShoulder: return "左肩"
        case .rightShoulder: return "右肩"
        case .leftElbow: return "左手肘"
        case .rightElbow: return "右手肘"
        case .leftWrist: return "左手腕"
        case .rightWrist: return "右手腕"
        case .root: return "骨盆中心"
        case .leftHip: return "左髖"
        case .rightHip: return "右髖"
        case .leftKnee: return "左膝"
        case .rightKnee: return "右膝"
        case .leftAnkle: return "左腳踝"
        case .rightAnkle: return "右腳踝"
        case .leftThumbTip: return "左拇指"
        case .leftIndexMCP: return "左食指根"
        case .rightThumbTip: return "右拇指"
        case .rightIndexMCP: return "右食指根"
        }
    }
}

/// Normalized 2D pose coordinates in view space (0...1, origin top-left)
nonisolated struct PoseSkeleton: Equatable, Sendable {
    var joints: [SkeletonJoint: CGPoint]
    var confidences: [SkeletonJoint: Float]
    /// Simulated or Vision-detected V-groove angle in degrees (0 = vertical up, positive = tilted toward trail shoulder)
    var detectedGripVAngle: Double
    /// Simulated or Vision-detected hand closeness ratio (1.0 = tightly unified, <0.6 = split hands)
    var handConnectionScore: Double

    init(
        joints: [SkeletonJoint: CGPoint] = [:],
        confidences: [SkeletonJoint: Float] = [:],
        detectedGripVAngle: Double = 20.0,
        handConnectionScore: Double = 0.92
    ) {
        self.joints = joints
        self.confidences = confidences
        self.detectedGripVAngle = detectedGripVAngle
        self.handConnectionScore = handConnectionScore
    }

    func point(for joint: SkeletonJoint) -> CGPoint? {
        guard let pt = joints[joint] else { return nil }
        let conf = confidences[joint] ?? 1.0
        return conf >= 0.15 ? pt : nil
    }

    static let boneConnections: [(SkeletonJoint, SkeletonJoint)] = [
        (.nose, .neck),
        (.neck, .leftShoulder),
        (.neck, .rightShoulder),
        (.leftShoulder, .leftElbow),
        (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow),
        (.rightElbow, .rightWrist),
        (.neck, .root),
        (.leftShoulder, .leftHip),
        (.rightShoulder, .rightHip),
        (.leftHip, .rightHip),
        (.leftHip, .leftKnee),
        (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee),
        (.rightKnee, .rightAnkle)
    ]
}

// MARK: - Checkpoint Evaluation Result

enum CheckStatus: String, Codable {
    case perfect
    case almost
    case needsCorrection

    var color: Color {
        switch self {
        case .perfect: return Color.green
        case .almost: return Color.orange
        case .needsCorrection: return Color.red
        }
    }

    var badgeText: String {
        switch self {
        case .perfect: return "標準！"
        case .almost: return "接近中"
        case .needsCorrection: return "需調整"
        }
    }

    var iconName: String {
        switch self {
        case .perfect: return "checkmark.circle.fill"
        case .almost: return "exclamationmark.triangle.fill"
        case .needsCorrection: return "xmark.octagon.fill"
        }
    }
}

struct CheckpointResult: Identifiable, Equatable {
    let id: String
    let title: String
    let currentValueText: String
    let targetValueText: String
    let progress: Double // 0.0 ... 1.0 closeness to ideal
    let status: CheckStatus
    let correctionTip: String
    let highlightedJoints: [SkeletonJoint]
}

struct StageEvaluationSummary: Equatable {
    let stageID: GolfStageID
    let checkpoints: [CheckpointResult]
    let overallAccuracy: Double // 0.0 ... 100.0
    let primaryCoachTip: String
    let isAllPassing: Bool
}

// MARK: - Stage Metadata & Mistake Contrast

struct MistakeContrastInfo {
    let badTitle: String
    let badDescription: String
    let badConsequence: String
    let goodTitle: String
    let goodDescription: String
    let proSecret: String
}

struct QuizQuestion {
    let question: String
    let options: [String]
    let correctIndex: Int
    let explanation: String
}

struct GolfStage: Identifiable {
    let id: GolfStageID
    let title: String
    let subtitle: String
    let chapterBadge: String
    let iconName: String
    let themeColor: Color
    let cameraPlacementTip: String
    let holdDurationRequired: Double
    let xpReward: Int
    let mistakeContrast: MistakeContrastInfo
    let quiz: QuizQuestion

    static let allStages: [GolfStage] = [
        GolfStage(
            id: .setup,
            title: "站姿與瞄準設定",
            subtitle: "Setup & Posture：打造穩定發力的地基",
            chapterBadge: "STAGE 1",
            iconName: "figure.golf",
            themeColor: Color(red: 0.16, green: 0.68, blue: 0.45),
            cameraPlacementTip: "請將手機立於正前方或側面約 2 公尺處，讓全身（頭到腳踝）完整入鏡。",
            holdDurationRequired: 2.5,
            xpReward: 150,
            mistakeContrast: MistakeContrastInfo(
                badTitle: "❌ 初學者常見：蹲馬桶或彎腰駝背",
                badDescription: "膝蓋過度彎曲、臀部下沉，或從腰部死彎導致背部圓拱，身體無法自由旋轉。",
                badConsequence: "容易打厚（啃地球）或上桿時身體被迫抬起造成剃頭球！",
                goodTitle: "✅ 黃金設定：從髖關節前傾 + 膝蓋微彈",
                goodDescription: "雙腳與肩同寬，背部保持自然挺直從髖部前傾約 32°~38°，雙手自然下垂於下巴正下方。",
                proSecret: "想像自己正坐在高腳吧台椅的邊緣，重心均勻踩在雙腳足弓前側！"
            ),
            quiz: QuizQuestion(
                question: "高爾夫準備站姿（Address）時，上半身前傾應該從哪個部位啟動？",
                options: [
                    "彎曲腰椎與低頭駝背",
                    "從髖關節（大腿根部）向前折疊，保持背部挺直",
                    "膝蓋大幅度蹲低像坐矮板凳"
                ],
                correctIndex: 1,
                explanation: "從髖關節前傾能維持脊椎角度穩定，讓肩膀在固定平面上順暢旋轉！"
            )
        ),
        GolfStage(
            id: .grip,
            title: "握桿方式與虎口檢查",
            subtitle: "Grip Mastery：唯一與球桿連結的方向盤",
            chapterBadge: "STAGE 2",
            iconName: "hand.raised.fingers.spread.fill",
            themeColor: Color(red: 0.18, green: 0.54, blue: 0.88),
            cameraPlacementTip: "正面面對鏡頭做好握桿準備姿勢，確保雙手與雙肩形成倒三角形。",
            holdDurationRequired: 2.5,
            xpReward: 180,
            mistakeContrast: MistakeContrastInfo(
                badTitle: "❌ 初學者常見：棒球雙手分開握、手掌死握",
                badDescription: "左右手距離過遠、虎口 V 字朝向左肩（過度弱勢）或朝向身體右側外（過度強勢）。",
                badConsequence: "擊球瞬間桿面極易翻轉失控，造成嚴重右曲球（Slice）或左勾球（Hook）！",
                goodTitle: "✅ 黃金握桿：雙手緊密一體、虎口指向右肩",
                goodDescription: "用手指而非掌心扣住握把，左右手大拇指與食指形成的 V 字型同步指向右肩與下巴之間。",
                proSecret: "如果握桿力道 10 分是最緊，理想握桿力道只有 4 分——像握著小鳥不讓牠飛走也不弄痛牠！"
            ),
            quiz: QuizQuestion(
                question: "採用中性標準握桿時，左右手拇指與食指形成的「虎口 V 字」應該指向哪裡？",
                options: [
                    "指向左肩外側",
                    "指向右耳與右肩之間（右手球員）",
                    "垂直指向地面"
                ],
                correctIndex: 1,
                explanation: "雙手虎口 V 字指向右肩與下巴之間，能讓桿面在擊球瞬間最自然地回正！"
            )
        ),
        GolfStage(
            id: .backswing,
            title: "上桿與轉肩蓄力",
            subtitle: "Backswing & Coil：扭轉核心、告別雞翅膀",
            chapterBadge: "STAGE 3",
            iconName: "arrow.triangle.2.circlepath.circle.fill",
            themeColor: Color(red: 0.94, green: 0.55, blue: 0.16),
            cameraPlacementTip: "正面對準鏡頭，做上桿至頂點（Top of Backswing）動作並定格檢查。",
            holdDurationRequired: 2.2,
            xpReward: 220,
            mistakeContrast: MistakeContrastInfo(
                badTitle: "❌ 初學者常見：只用手抬桿 + 身體左右橫移 (Sway)",
                badDescription: "肩膀沒有轉動，單靠雙手把球桿舉起來，左手肘彎曲塌陷，骨盆往右外側大幅滑移。",
                badConsequence: "完全沒有扭力儲存，下桿必定由外向內砍球（Out-to-In），距離短又歪！",
                goodTitle: "✅ 黃金上桿：左肩轉至下巴下方 + 左臂延伸",
                goodDescription: "以脊椎為中心轉動胸口與肩膀，左手臂自然延伸不鎖死，雙手高於右肩、重心踩穩右腳內側。",
                proSecret: "感覺左肩往右腳內側轉過去，就像把身體擰成一條蓄滿力量的彈簧！"
            ),
            quiz: QuizQuestion(
                question: "上桿到頂點（Top）時，為了避免「橫移搖晃 (Sway)」，重心應該踩在哪裡？",
                options: [
                    "右腳外側腳刀（甚至翻腳踝）",
                    "右腳內側足弓，保持右膝穩定支撐",
                    "完全留在左腳尖"
                ],
                correctIndex: 1,
                explanation: "右腳內側穩定支撐能讓骨盆原地旋轉蓄力，下桿時才能順暢往目標方向蹬地轉移！"
            )
        ),
        GolfStage(
            id: .impact,
            title: "下桿與擊球瞬間",
            subtitle: "Downswing & Impact：重心前移與延遲釋放",
            chapterBadge: "STAGE 4",
            iconName: "bolt.circle.fill",
            themeColor: Color(red: 0.88, green: 0.28, blue: 0.36),
            cameraPlacementTip: "面對鏡頭做出「擊球瞬間 (Impact)」分解定格動作，體驗下半身領先感。",
            holdDurationRequired: 2.2,
            xpReward: 260,
            mistakeContrast: MistakeContrastInfo(
                badTitle: "❌ 初學者常見：重心留在後腳「撈球」与提早釋放",
                badDescription: "想把球挑高而重心後退、手腕在下桿初期就提前解開拋出（Casting），雙手落後於球。",
                badConsequence: "桿底先撞擊地面後面的草皮（打肥 Fat Shot）或球桿上升擊中球頂（Topping）！",
                goodTitle: "✅ 黃金擊球：髖部先轉、雙手領先球位 (Shaft Lean)",
                goodDescription: "下半身重心率先移至左腳，髖部微開，雙手在擊球瞬間位於球位稍微前方，頭部穩定留在球後。",
                proSecret: "鐵桿是『向下擠壓擊球』再由桿面角度讓球起飛，千萬不要自己動手去把球撈起來！"
            ),
            quiz: QuizQuestion(
                question: "鐵桿擊球瞬間（Impact）與準備站姿（Address）相比，身體有什麼關鍵差異？",
                options: [
                    "擊球瞬間與準備站姿完全一模一樣",
                    "擊球時重心已轉移到左腳、骨盆微向目標轉開、雙手略微領先球頭",
                    "擊球時頭部應該跟著球一起往前衝出去"
                ],
                correctIndex: 1,
                explanation: "職業選手在 Impact 時骨盆已轉開約 35°、重心 75% 在左腳，雙手領先球頭形成紮實擠壓！"
            )
        ),
        GolfStage(
            id: .finish,
            title: "送桿與收桿平衡",
            subtitle: "Follow-through & Finish：帥氣定格 3 秒鐘",
            chapterBadge: "STAGE 5",
            iconName: "trophy.circle.fill",
            themeColor: Color(red: 0.58, green: 0.34, blue: 0.90),
            cameraPlacementTip: "完成揮桿後做出收桿姿勢（Finish），面向目標方向並穩定維持平衡！",
            holdDurationRequired: 3.0,
            xpReward: 300,
            mistakeContrast: MistakeContrastInfo(
                badTitle: "❌ 初學者常見：收桿重心後倒、雙手急煞車",
                badDescription: "擊完球後身體往後仰、左腳站不穩東倒西歪，或雙手停在半空中不敢收桿。",
                badConsequence: "不僅損失揮桿速度，還容易拉傷下背與手肘，球路也忽左忽右！",
                goodTitle: "✅ 黃金收桿：胸口與皮帶扣面向目標、右腳尖點地",
                goodDescription: "90% 重心穩穩站在左腳外側，右腳跟自然抬起僅用腳尖輕點平衡，雙手優雅收在左耳後方。",
                proSecret: "如果在收桿後能輕鬆單腳般穩定站立 3 秒看著球飛向果嶺，代表你整趟揮桿節奏超完美！"
            ),
            quiz: QuizQuestion(
                question: "完美收桿（Finish）時，身體重心與右腳應該呈現什麼狀態？",
                options: [
                    "重心平均分佈在雙腳，雙腳腳掌貼死地面",
                    "約 90% 重心在左腳，右腳跟完全抬起、右膝靠攏左膝",
                    "重心留在右腳，上半身往後仰看天空"
                ],
                correctIndex: 1,
                explanation: "完整釋放重心到左腳、右腳尖輕點地面，能確保揮桿力量完全貫穿擊球區！"
            )
        )
    ]

    static func stage(for id: GolfStageID) -> GolfStage {
        allStages.first(where: { $0.id == id }) ?? allStages[0]
    }
}

// MARK: - Practice & Clearance Badges

struct PracticeBadge: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let englishSubtitle: String
    let description: String
    let requiredSessions: Int
    let requiresAllStagesCleared: Bool
    let iconName: String
    let accentColors: [Color]

    func isUnlocked(totalSessions: Int, clearedStagesCount: Int) -> Bool {
        let safeSessions = max(0, totalSessions)
        let safeCleared = max(0, clearedStagesCount)
        if requiresAllStagesCleared && safeCleared >= 5 {
            return true
        }
        return safeSessions >= requiredSessions
    }

    func progress(totalSessions: Int, clearedStagesCount: Int) -> Double {
        if isUnlocked(totalSessions: totalSessions, clearedStagesCount: clearedStagesCount) {
            return 1.0
        }
        let safeSessions = max(0, totalSessions)
        return min(1.0, max(0.0, Double(safeSessions) / Double(max(1, requiredSessions))))
    }

    func progressLabel(totalSessions: Int, clearedStagesCount: Int) -> String {
        if isUnlocked(totalSessions: totalSessions, clearedStagesCount: clearedStagesCount) {
            return "已解鎖"
        }
        let safeSessions = max(0, totalSessions)
        return "\(safeSessions) / \(requiredSessions) 次練習"
    }

    static let allBadges: [PracticeBadge] = [
        PracticeBadge(
            id: "badge_first_tee",
            title: "初踏果嶺銅章",
            englishSubtitle: "FIRST TEE ROOKIE",
            description: "完成第 1 次姿勢訂正練習，正式開啟高爾夫揮桿進化之路！",
            requiredSessions: 1,
            requiresAllStagesCleared: false,
            iconName: "flag.fill",
            accentColors: [Color(red: 0.80, green: 0.52, blue: 0.32), Color(red: 0.62, green: 0.36, blue: 0.20)]
        ),
        PracticeBadge(
            id: "badge_range_regular",
            title: "鐵桿練習生銀章",
            englishSubtitle: "RANGE REGULAR",
            description: "累計完成 3 次練習通關，站姿與握桿肌肉記憶逐漸成形。",
            requiredSessions: 3,
            requiresAllStagesCleared: false,
            iconName: "figure.golf",
            accentColors: [Color(red: 0.75, green: 0.82, blue: 0.90), Color(red: 0.50, green: 0.58, blue: 0.68)]
        ),
        PracticeBadge(
            id: "badge_fairway_breaker",
            title: "球道突破者金章",
            englishSubtitle: "FAIRWAY BREAKER",
            description: "累計完成 5 次練習通關，徹底告別雞翅膀與重心搖晃！",
            requiredSessions: 5,
            requiresAllStagesCleared: false,
            iconName: "medal.fill",
            accentColors: [Color(red: 0.98, green: 0.78, blue: 0.22), Color(red: 0.88, green: 0.52, blue: 0.12)]
        ),
        PracticeBadge(
            id: "badge_golden_swing",
            title: "翡翠揮桿大師章",
            englishSubtitle: "EMERALD SWING PRO",
            description: "累計完成 10 次練習通關，上桿蓄力與下桿釋放如行雲流水。",
            requiredSessions: 10,
            requiresAllStagesCleared: false,
            iconName: "sparkles",
            accentColors: [Color(red: 0.16, green: 0.85, blue: 0.56), Color(red: 0.08, green: 0.55, blue: 0.42)]
        ),
        PracticeBadge(
            id: "badge_grand_slam",
            title: "大滿貫傳奇王冠",
            englishSubtitle: "GRAND SLAM LEGEND",
            description: "累計完成 20 次練習或全數通過 5 大關卡，榮登高球學院最高殿堂！",
            requiredSessions: 20,
            requiresAllStagesCleared: true,
            iconName: "crown.fill",
            accentColors: [Color(red: 0.68, green: 0.42, blue: 0.98), Color(red: 0.96, green: 0.36, blue: 0.62)]
        )
    ]

    static func highestUnlocked(totalSessions: Int, clearedStagesCount: Int) -> PracticeBadge? {
        allBadges.last(where: { $0.isUnlocked(totalSessions: totalSessions, clearedStagesCount: clearedStagesCount) })
    }

    static func nextTargetBadge(totalSessions: Int, clearedStagesCount: Int) -> PracticeBadge? {
        allBadges.first(where: { !$0.isUnlocked(totalSessions: totalSessions, clearedStagesCount: clearedStagesCount) })
    }
}

// MARK: - SwiftData Persistence Models

@Model
final class StageRecord {
    var stageRawValue: Int
    var stars: Int
    var bestAccuracy: Double
    var completedCount: Int
    var quizPassed: Bool
    var lastPlayedAt: Date

    init(
        stageRawValue: Int,
        stars: Int = 0,
        bestAccuracy: Double = 0,
        completedCount: Int = 0,
        quizPassed: Bool = false,
        lastPlayedAt: Date = .now
    ) {
        self.stageRawValue = stageRawValue
        self.stars = stars
        self.bestAccuracy = bestAccuracy
        self.completedCount = completedCount
        self.quizPassed = quizPassed
        self.lastPlayedAt = lastPlayedAt
    }

    var stageID: GolfStageID {
        GolfStageID(rawValue: stageRawValue) ?? .setup
    }
}

@Model
final class PlayerProfile {
    var playerName: String
    var playerBio: String
    var avatarSymbol: String
    var hasCompletedOnboarding: Bool
    var totalPracticeSessions: Int
    var totalXP: Int
    var preferredGripRaw: String
    var isLeftHanded: Bool
    var totalCorrectionsCount: Int
    var createdAt: Date

    init(
        playerName: String = "高球新星",
        playerBio: String = "目標建立穩定站姿與黃金揮桿平面，朝破百邁進！",
        avatarSymbol: String = "figure.golf",
        hasCompletedOnboarding: Bool = false,
        totalPracticeSessions: Int = 0,
        totalXP: Int = 0,
        preferredGripRaw: String = GripStyle.overlap.rawValue,
        isLeftHanded: Bool = false,
        totalCorrectionsCount: Int = 0,
        createdAt: Date = .now
    ) {
        self.playerName = playerName
        self.playerBio = playerBio
        self.avatarSymbol = avatarSymbol
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.totalPracticeSessions = totalPracticeSessions
        self.totalXP = totalXP
        self.preferredGripRaw = preferredGripRaw
        self.isLeftHanded = isLeftHanded
        self.totalCorrectionsCount = totalCorrectionsCount
        self.createdAt = createdAt
    }

    static let defaultPlayerName = "高球新星"
    static let defaultPlayerBio = "目標建立穩定站姿與黃金揮桿平面，朝破百邁進！"

    static func sanitizeName(_ rawName: String) -> String {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultPlayerName : trimmed
    }

    static func sanitizeBio(_ rawBio: String) -> String {
        let trimmed = rawBio.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultPlayerBio : trimmed
    }

    func applyLoginProfile(name: String, bio: String, avatar: String) {
        self.playerName = Self.sanitizeName(name)
        self.playerBio = Self.sanitizeBio(bio)
        self.avatarSymbol = avatar.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "figure.golf" : avatar
        self.hasCompletedOnboarding = true
    }

    var preferredGrip: GripStyle {
        get { GripStyle(rawValue: preferredGripRaw) ?? .overlap }
        set { preferredGripRaw = newValue.rawValue }
    }

    var level: Int {
        max(1, (max(0, totalXP) / 250) + 1)
    }

    var currentLevelProgress: Double {
        Double(max(0, totalXP) % 250) / 250.0
    }

    var xpToNextLevel: Int {
        250 - (max(0, totalXP) % 250)
    }

    var rankTitle: String {
        switch level {
        case 1: return "🌱 練習場初心者"
        case 2: return "⛳️ 果嶺見習生"
        case 3: return "🏌️ 球道探索者"
        case 4: return "🦅 博蒂挑戰者"
        default: return "🏆 高爾夫姿勢大師"
        }
    }
}
