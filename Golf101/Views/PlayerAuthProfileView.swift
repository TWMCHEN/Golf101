//
//  PlayerAuthProfileView.swift
//  Golf101
//
//  Created by Golf101 AI Coach on 2026/10/23.
//

import SwiftUI

struct PlayerLoginProfileSheet: View {
    @Bindable var profile: PlayerProfile
    let clearedStagesCount: Int
    let isInitialOnboarding: Bool
    var onConfirmLogin: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var draftName: String = ""
    @State private var draftBio: String = ""
    @State private var draftAvatar: String = "figure.golf"

    private static let avatarChoices: [(symbol: String, label: String)] = [
        ("figure.golf", "標準揮桿"),
        ("flag.2.crossed.fill", "果嶺雙旗"),
        ("trophy.fill", "冠軍金盃"),
        ("flame.fill", "熱血強打"),
        ("crown.fill", "大師皇冠")
    ]

    private static let presetBios: [String] = [
        "初學高爾夫，目標建立標準站姿與穩定轉肩！",
        "擺脫右曲球 Slice 與雞翅膀，練出流暢收桿！",
        "目標三個月內破百，專注擊球瞬間桿身前傾！"
    ]

    private var unlockedBadgesCount: Int {
        PracticeBadge.allBadges.filter {
            $0.isUnlocked(totalSessions: profile.totalPracticeSessions, clearedStagesCount: clearedStagesCount)
        }.count
    }

    private var highestBadge: PracticeBadge? {
        PracticeBadge.highestUnlocked(
            totalSessions: profile.totalPracticeSessions,
            clearedStagesCount: clearedStagesCount
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.08, blue: 0.13),
                        Color(red: 0.07, green: 0.17, blue: 0.14),
                        Color(red: 0.05, green: 0.10, blue: 0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 1. Welcome Banner
                        VStack(spacing: 6) {
                            Text(isInitialOnboarding ? "WELCOME TO GOLF 101" : "GOLFER PASSPORT & BADGES")
                                .font(.caption.weight(.black))
                                .tracking(2)
                                .foregroundStyle(.mint)

                            Text(isInitialOnboarding ? "建立您的專屬球員登入證" : "球員個人檔案與通關徽章館")
                                .font(.title2.weight(.heavy))
                                .foregroundStyle(.white)

                            Text("設定暱稱與高球目標簡介，隨著關卡通關累積解鎖專屬榮譽徽章")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.70))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 6)

                        // 2. Live Golfer Passport Card Preview
                        golferPassportCardPreview

                        // 3. Login / Profile Form Section
                        loginFormSection

                        // 4. Practice Count & Clearance Badges Showcase
                        badgeCabinetSection

                        // 5. Primary Login / Save CTA Button
                        Button {
                            saveAndProceed()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                Text(isInitialOnboarding ? "完成登入並進入闖關地圖" : "儲存球員設定並返回")
                            }
                            .font(.headline.weight(.heavy))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.16, green: 0.82, blue: 0.52), Color(red: 0.10, green: 0.62, blue: 0.42)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: 18)
                            )
                            .foregroundStyle(.black)
                            .shadow(color: .green.opacity(0.35), radius: 10, y: 4)
                        }
                        .accessibilityIdentifier("ConfirmPlayerLoginButton")
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                }
            }
            .navigationTitle(isInitialOnboarding ? "球員登入" : "球員檔案與徽章")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if !isInitialOnboarding {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") {
                            saveAndProceed()
                        }
                        .fontWeight(.bold)
                        .foregroundStyle(.mint)
                    }
                }
            }
            .onAppear {
                draftName = profile.playerName
                draftBio = profile.playerBio
                draftAvatar = profile.avatarSymbol
            }
        }
    }

    // MARK: - 1. Live Golfer Passport Card Preview

    private var golferPassportCardPreview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                // Avatar Emblem
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.16, green: 0.85, blue: 0.56), Color(red: 0.08, green: 0.52, blue: 0.44)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)

                    Image(systemName: draftAvatar)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.black)
                }
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.35), lineWidth: 2)
                )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(PlayerProfile.sanitizeName(draftName))
                            .font(.title3.weight(.black))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text("Lv.\(profile.level)")
                            .font(.caption2.weight(.black))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.yellow, in: Capsule())
                            .foregroundStyle(.black)
                    }

                    Text(profile.rankTitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.mint)

                    Text(PlayerProfile.sanitizeBio(draftBio))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(2)
                        .padding(.top, 2)
                }

                Spacer(minLength: 0)
            }

            Divider()
                .background(.white.opacity(0.16))

            // Active Badge & Practice Stats Bar
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: highestBadge?.iconName ?? "shield.lefthalf.filled")
                        .foregroundStyle(highestBadge != nil ? .yellow : .white.opacity(0.5))
                        .font(.subheadline.weight(.bold))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("目前配戴徽章")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                        Text(highestBadge?.title ?? "尚未解鎖（完成 1 次關卡通關即可獲得）")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text("累計關卡通關")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("\(profile.totalPracticeSessions) 次 • \(unlockedBadgesCount)/\(PracticeBadge.allBadges.count) 徽章")
                        .font(.caption.monospacedDigit().weight(.heavy))
                        .foregroundStyle(.yellow)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.11, green: 0.18, blue: 0.24),
                            Color(red: 0.08, green: 0.13, blue: 0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [Color.mint.opacity(0.65), Color.white.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
    }

    // MARK: - 2. Login Form (Avatar, Nickname, Bio, Grip Preference)

    private var loginFormSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("個人資料設定", systemImage: "person.text.rectangle.fill")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(.white)

            // Avatar Icon Selector
            VStack(alignment: .leading, spacing: 6) {
                Text("選擇代表圖章")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.75))

                HStack(spacing: 10) {
                    ForEach(Self.avatarChoices, id: \.symbol) { item in
                        let isSelected = draftAvatar == item.symbol
                        Button {
                            withAnimation(.spring(duration: 0.3)) {
                                draftAvatar = item.symbol
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: item.symbol)
                                    .font(.headline.weight(.bold))
                                    .frame(width: 40, height: 40)
                                    .background(
                                        isSelected ? Color.mint : Color.white.opacity(0.10),
                                        in: Circle()
                                    )
                                    .foregroundStyle(isSelected ? .black : .white)

                                Text(item.label)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(isSelected ? .mint : .white.opacity(0.65))
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }

            // Nickname Input
            VStack(alignment: .leading, spacing: 6) {
                Text("球員暱稱 (Nickname)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.75))

                HStack {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.mint)
                    TextField("請輸入您的暱稱，例如：Mike Chen", text: $draftName)
                        .foregroundStyle(.white)
                        .font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("PlayerNicknameField")
                }
                .padding(12)
                .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
            }

            // Bio Input & Preset Chips
            VStack(alignment: .leading, spacing: 6) {
                Text("個人高球簡介／練習目標 (Bio)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.75))

                HStack(alignment: .top) {
                    Image(systemName: "quote.opening")
                        .foregroundStyle(.mint)
                        .padding(.top, 2)
                    TextField("寫下您的高球簡介或目標...", text: $draftBio, axis: .vertical)
                        .lineLimit(2...3)
                        .foregroundStyle(.white)
                        .font(.subheadline)
                        .accessibilityIdentifier("PlayerBioField")
                }
                .padding(12)
                .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )

                // Quick Preset Bio Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Self.presetBios, id: \.self) { preset in
                            Button {
                                draftBio = preset
                            } label: {
                                Text("✨ \(preset)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.mint)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.mint.opacity(0.14), in: Capsule())
                            }
                        }
                    }
                }
            }

            // Preferred Grip Selector
            VStack(alignment: .leading, spacing: 6) {
                Text("慣用握桿流派")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.75))

                HStack(spacing: 8) {
                    ForEach(GripStyle.allCases) { style in
                        let isSelected = profile.preferredGrip == style
                        Button {
                            profile.preferredGrip = style
                        } label: {
                            Text(style.shortName)
                                .font(.caption.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(
                                    isSelected ? Color.mint.opacity(0.85) : Color.black.opacity(0.35),
                                    in: RoundedRectangle(cornerRadius: 12)
                                )
                                .foregroundStyle(isSelected ? .black : .white)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        )
    }

    // MARK: - 3. Stage Clearance Badges Showcase

    private var badgeCabinetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("關卡通關徽章館", systemImage: "medal.fill")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.yellow)

                Spacer()
            }

            if let nextBadge = PracticeBadge.nextTargetBadge(
                totalSessions: profile.totalPracticeSessions,
                clearedStagesCount: clearedStagesCount
            ) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.mint)
                        .font(.caption)
                    Text("距離解鎖「\(nextBadge.title)」還差 \(max(0, nextBadge.requiredSessions - profile.totalPracticeSessions)) 次關卡通關！")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.mint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                    Text("恭喜！您已全數解鎖所有高爾夫練習與通關榮譽徽章！")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.yellow)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.yellow.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
            }

            // 5 Badges List
            VStack(spacing: 10) {
                ForEach(PracticeBadge.allBadges) { badge in
                    badgeRowView(for: badge)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        )
    }

    private func badgeRowView(for badge: PracticeBadge) -> some View {
        let unlocked = badge.isUnlocked(
            totalSessions: profile.totalPracticeSessions,
            clearedStagesCount: clearedStagesCount
        )
        let prog = badge.progress(
            totalSessions: profile.totalPracticeSessions,
            clearedStagesCount: clearedStagesCount
        )
        let fillGradient: LinearGradient = unlocked
            ? LinearGradient(colors: badge.accentColors, startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(colors: [Color.white.opacity(0.10), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom)
        let barGradient: LinearGradient = unlocked
            ? LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
            : LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
        let strokeColor: Color = unlocked ? badge.accentColors[0].opacity(0.55) : Color.white.opacity(0.08)

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(fillGradient)
                    .frame(width: 48, height: 48)

                Image(systemName: unlocked ? badge.iconName : "lock.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(unlocked ? .white : .white.opacity(0.35))
            }
            .overlay(
                Circle()
                    .stroke(unlocked ? Color.white.opacity(0.6) : Color.white.opacity(0.12), lineWidth: 1.5)
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(badge.title)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(unlocked ? .white : .white.opacity(0.55))

                    Text(badge.englishSubtitle)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(unlocked ? .mint : .white.opacity(0.35))

                    Spacer()

                    Text(badge.progressLabel(totalSessions: profile.totalPracticeSessions, clearedStagesCount: clearedStagesCount))
                        .font(.caption2.monospacedDigit().weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            unlocked ? Color.green.opacity(0.28) : Color.white.opacity(0.10),
                            in: Capsule()
                        )
                        .foregroundStyle(unlocked ? .green : .white.opacity(0.65))
                }

                Text(badge.description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(unlocked ? 0.80 : 0.45))

                GeometryReader { barGeo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                        Capsule()
                            .fill(barGradient)
                            .frame(width: barGeo.size.width * max(0.0, min(1.0, prog)))
                    }
                }
                .frame(height: 5)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(unlocked ? Color.white.opacity(0.10) : Color.black.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(strokeColor, lineWidth: 1.2)
                )
        )
    }

    // MARK: - Save & Dismiss

    private func saveAndProceed() {
        profile.applyLoginProfile(name: draftName, bio: draftBio, avatar: draftAvatar)
        onConfirmLogin?()
        dismiss()
    }
}
