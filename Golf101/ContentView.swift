//
//  ContentView.swift
//  Golf101
//
//  Created by Hsiaoyi Chen on 2026/10/23.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [PlayerProfile]
    @Query(sort: \StageRecord.stageRawValue) private var stageRecords: [StageRecord]

    @State private var selectedStageForPlay: GolfStage? = nil
    @State private var selectedStageForComparison: GolfStage? = nil
    @State private var showGripGuideSheet: Bool = false

    private var activeProfile: PlayerProfile {
        if let first = profiles.first {
            return first
        }
        let created = PlayerProfile()
        modelContext.insert(created)
        return created
    }

    private var totalStars: Int {
        stageRecords.map(\.stars).reduce(0, +)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Fairway Green & Sky Cartoon Gradient Background
                LinearGradient(
                    colors: [
                        Color(red: 0.06, green: 0.14, blue: 0.22),
                        Color(red: 0.07, green: 0.23, blue: 0.17),
                        Color(red: 0.05, green: 0.16, blue: 0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 1. Golfer Profile & XP Header Card
                        playerHeaderCard(profile: activeProfile)

                        // 2. Quick Grip Style Selector Banner
                        gripBannerCard(profile: activeProfile)

                        // 3. Section Header
                        HStack {
                            Label("AI 姿勢訂正闖關地圖", systemImage: "flag.2.crossed.fill")
                                .font(.headline.weight(.heavy))
                                .foregroundStyle(.white)
                            Spacer()
                            Text("支援 Vision AI 相機 & 互動模擬")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.green.opacity(0.16), in: Capsule())
                        }
                        .padding(.horizontal, 4)

                        // 4. Five Golf Stages Progression Map
                        VStack(spacing: 16) {
                            ForEach(GolfStage.allStages) { stage in
                                let rec = record(for: stage.id)
                                let isUnlocked = isStageUnlocked(stage.id)
                                StageMapCardView(
                                    stage: stage,
                                    record: rec,
                                    isUnlocked: isUnlocked,
                                    onOpenComparison: {
                                        selectedStageForComparison = stage
                                    },
                                    onStartStage: {
                                        selectedStageForPlay = stage
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .navigationTitle("Golf 101 揮桿闖關學院")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(item: $selectedStageForPlay) { stage in
                StagePlayView(
                    stage: stage,
                    profile: activeProfile,
                    stageRecord: record(for: stage.id),
                    onStageCompleted: { stars, accuracy, quizPassed, xpGained in
                        saveStageCompletion(
                            stageID: stage.id,
                            stars: stars,
                            accuracy: accuracy,
                            quizPassed: quizPassed,
                            xpGained: xpGained
                        )
                    }
                )
            }
            .sheet(item: $selectedStageForComparison) { stage in
                PostureComparisonSheet(stage: stage, gripStyle: activeProfile.preferredGrip)
            }
            .sheet(isPresented: $showGripGuideSheet) {
                GripEncyclopediaSheet(profile: activeProfile)
            }
            .onAppear {
                ensureProfileExists()
            }
        }
    }

    // MARK: - Player Header Card

    private func playerHeaderCard(profile: PlayerProfile) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 62, height: 62)

                    Text("🏌️")
                        .font(.system(size: 32))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(profile.rankTitle)
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(.yellow)
                        Text("Lv.\(profile.level)")
                            .font(.caption.weight(.black))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.yellow, in: Capsule())
                            .foregroundStyle(.black)
                    }

                    Text("高爾夫初學者 AI 訓練營")
                        .font(.title3.weight(.black))
                        .foregroundStyle(.white)

                    // XP Progress bar
                    VStack(alignment: .leading, spacing: 4) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.16))
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [.yellow, .orange],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * profile.currentLevelProgress)
                            }
                        }
                        .frame(height: 8)

                        HStack {
                            Text("總經驗值 \(profile.totalXP) XP")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.75))
                            Spacer()
                            Text("距離下一級還差 \(profile.xpToNextLevel) XP")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
            }

            Divider()
                .background(.white.opacity(0.15))

            // Stats Row
            HStack(spacing: 12) {
                statPill(
                    icon: "star.fill",
                    iconColor: .yellow,
                    title: "收集星星",
                    value: "\(totalStars) / 15"
                )
                statPill(
                    icon: "flag.checkered",
                    iconColor: .green,
                    title: "已通關卡",
                    value: "\(stageRecords.filter { $0.stars > 0 }.count) / 5"
                )
                statPill(
                    icon: "wand.and.stars",
                    iconColor: .cyan,
                    title: "動作訂正",
                    value: "\(profile.totalCorrectionsCount) 次"
                )
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.09))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        )
    }

    private func statPill(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .font(.subheadline)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
                Text(value)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Grip Style Banner

    private func gripBannerCard(profile: PlayerProfile) -> some View {
        Button {
            showGripGuideSheet = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "hand.raised.fingers.spread.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.blue.gradient, in: RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("目前握桿設定：\(profile.preferredGrip.rawValue)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    Text("點此切換「重疊式 / 互鎖式 / 十指式」並查看虎口 V 字教學")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.blue.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.blue.opacity(0.45), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - SwiftData Persistence Helpers

    private func ensureProfileExists() {
        if profiles.isEmpty {
            let newProfile = PlayerProfile()
            modelContext.insert(newProfile)
        }
    }

    private func record(for stageID: GolfStageID) -> StageRecord? {
        stageRecords.first(where: { $0.stageRawValue == stageID.rawValue })
    }

    private func isStageUnlocked(_ stageID: GolfStageID) -> Bool {
        // Allow beginners to either play sequentially or jump into any of the 5 fundamentals freely
        return true
    }

    private func saveStageCompletion(
        stageID: GolfStageID,
        stars: Int,
        accuracy: Double,
        quizPassed: Bool,
        xpGained: Int
    ) {
        let profile = activeProfile
        profile.totalXP += xpGained

        if let existing = record(for: stageID) {
            existing.stars = max(existing.stars, stars)
            existing.bestAccuracy = max(existing.bestAccuracy, accuracy)
            existing.completedCount += 1
            existing.quizPassed = existing.quizPassed || quizPassed
            existing.lastPlayedAt = .now
        } else {
            let newRecord = StageRecord(
                stageRawValue: stageID.rawValue,
                stars: stars,
                bestAccuracy: accuracy,
                completedCount: 1,
                quizPassed: quizPassed,
                lastPlayedAt: .now
            )
            modelContext.insert(newRecord)
        }
        try? modelContext.save()
    }
}

// MARK: - Stage Map Card View

struct StageMapCardView: View {
    let stage: GolfStage
    let record: StageRecord?
    let isUnlocked: Bool
    let onOpenComparison: () -> Void
    let onStartStage: () -> Void

    private var earnedStars: Int {
        record?.stars ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                // Stage Icon Badge
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(stage.themeColor.gradient)
                        .frame(width: 56, height: 56)
                    Image(systemName: stage.iconName)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(stage.chapterBadge)
                            .font(.caption2.weight(.black))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(stage.themeColor.opacity(0.25), in: Capsule())
                            .foregroundStyle(stage.themeColor)

                        if let record, record.bestAccuracy > 0 {
                            Text("最佳 \(Int(record.bestAccuracy))%")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.green)
                        }

                        Spacer()

                        // 3-Star display
                        HStack(spacing: 3) {
                            ForEach(1...3, id: \.self) { idx in
                                Image(systemName: idx <= earnedStars ? "star.fill" : "star")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(idx <= earnedStars ? .yellow : .white.opacity(0.25))
                            }
                        }
                    }

                    Text(stage.title)
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(.white)

                    Text(stage.subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }

            // Common Mistake Highlight Box
            HStack(spacing: 8) {
                Image(systemName: "BandAid.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
                Text(stage.mistakeContrast.badTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                Spacer()
                Text("+\(stage.xpReward) XP")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.yellow)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.26), in: RoundedRectangle(cornerRadius: 12))

            // Action Buttons
            HStack(spacing: 10) {
                Button(action: onOpenComparison) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.tv.fill")
                        Text("錯誤 vs 標準動畫")
                    }
                    .font(.caption.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
                }

                Button(action: onStartStage) {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.viewfinder")
                        Text(earnedStars > 0 ? "再次挑戰" : "開始闖關訂正")
                    }
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(stage.themeColor.gradient, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(
                            earnedStars == 3 ? Color.yellow.opacity(0.6) : stage.themeColor.opacity(0.35),
                            lineWidth: 1.5
                        )
                )
        )
    }
}

// MARK: - Grip Style Encyclopedia & Selector Sheet

struct GripEncyclopediaSheet: View {
    @Bindable var profile: PlayerProfile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("選擇最適合你的握桿方式，Stage 2 將依照你的選擇自動調整 AI 虎口與雙手貼合判定標準！")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    ForEach(GripStyle.allCases) { style in
                        let isSelected = profile.preferredGrip == style
                        Button {
                            withAnimation {
                                profile.preferredGrip = style
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(style.rawValue)
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if isSelected {
                                        Label("使用中", systemImage: "checkmark.circle.fill")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.green)
                                    }
                                }

                                Text(style.recommendationTag)
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.15), in: Capsule())
                                    .foregroundStyle(.blue)

                                Text(style.detailDescription)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)

                                HStack {
                                    Image(systemName: "angle")
                                        .foregroundStyle(.orange)
                                    Text("理想虎口 V 字角度：右偏 \(Int(style.idealVAngleRange.lowerBound))° ~ \(Int(style.idealVAngleRange.upperBound))°")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.primary)
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color(.secondarySystemBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2.5)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 12)
            }
            .navigationTitle("三大高爾夫握桿流派")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}

// Allow GolfStage to work with navigationDestination(item:) and sheet(item:)
extension GolfStage: Equatable, Hashable {
    static func == (lhs: GolfStage, rhs: GolfStage) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [PlayerProfile.self, StageRecord.self, Item.self], inMemory: true)
}
