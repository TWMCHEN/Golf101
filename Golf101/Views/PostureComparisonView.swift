//
//  PostureComparisonView.swift
//  Golf101
//
//  Created by Golf101 AI Coach on 2026/10/23.
//

import SwiftUI
import Combine

struct PostureComparisonSheet: View {
    let stage: GolfStage
    let gripStyle: GripStyle
    @Environment(\.dismiss) private var dismiss

    @State private var morphProgress: CGFloat = 0.0 // 0 = Bad Pose, 1 = Good Pose
    @State private var isAutoPlaying: Bool = true
    private let timer = Timer.publish(every: 2.2, on: .main, in: .common).autoconnect()

    private var interpolatedSkeleton: PoseSkeleton {
        let bad = PostureEvaluator.presetSkeleton(for: stage.id, mode: .beginnerMistake)
        let good = PostureEvaluator.presetSkeleton(for: stage.id, mode: .idealPro)

        var blended: [SkeletonJoint: CGPoint] = [:]
        for joint in SkeletonJoint.allCases {
            if let bPt = bad.joints[joint], let gPt = good.joints[joint] {
                blended[joint] = CGPoint(
                    x: bPt.x + (gPt.x - bPt.x) * morphProgress,
                    y: bPt.y + (gPt.y - bPt.y) * morphProgress
                )
            }
        }
        let vAngle = bad.detectedGripVAngle + (good.detectedGripVAngle - bad.detectedGripVAngle) * Double(morphProgress)
        let conn = bad.handConnectionScore + (good.handConnectionScore - bad.handConnectionScore) * Double(morphProgress)
        return PoseSkeleton(joints: blended, detectedGripVAngle: vAngle, handConnectionScore: conn)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Header Banner
                    HStack(spacing: 12) {
                        Image(systemName: stage.iconName)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 54, height: 54)
                            .background(stage.themeColor.gradient, in: RoundedRectangle(cornerRadius: 16))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(stage.chapterBadge) 動作對比教室")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(stage.themeColor)
                            Text(stage.title)
                                .font(.title3.weight(.heavy))
                            Text("觀察常見錯誤如何一步步調整為標準姿勢")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)

                    // Animated Cartoon Golfer Comparison Stage
                    ZStack(alignment: .top) {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.08, green: 0.14, blue: 0.22),
                                        Color(red: 0.10, green: 0.24, blue: 0.19)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 310)

                        let currentEval = PostureEvaluator.evaluate(
                            skeleton: interpolatedSkeleton,
                            stageID: stage.id,
                            gripStyle: gripStyle
                        )

                        SkeletonOverlayView(
                            stageID: stage.id,
                            currentSkeleton: .constant(interpolatedSkeleton),
                            idealSkeleton: PostureEvaluator.presetSkeleton(for: stage.id, mode: .idealPro),
                            evaluation: currentEval,
                            isInteractiveMode: false
                        )
                        .frame(height: 310)

                        // Status Pill on top of animation
                        HStack {
                            Label(
                                morphProgress > 0.5 ? "標準黃金動作 (PRO)" : "初學者常見 NG 動作",
                                systemImage: morphProgress > 0.5 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
                            )
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                (morphProgress > 0.5 ? Color.green : Color.red).opacity(0.9),
                                in: Capsule()
                            )

                            Spacer()

                            Button {
                                isAutoPlaying.toggle()
                            } label: {
                                Label(isAutoPlaying ? "自動播放中" : "已暫停", systemImage: isAutoPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.ultraThinMaterial, in: Capsule())
                            }
                        }
                        .padding(14)
                    }
                    .padding(.horizontal)
                    .onReceive(timer) { _ in
                        guard isAutoPlaying else { return }
                        withAnimation(.easeInOut(duration: 1.1)) {
                            morphProgress = morphProgress < 0.5 ? 1.0 : 0.0
                        }
                    }

                    // Manual Toggle Buttons
                    HStack(spacing: 12) {
                        Button {
                            isAutoPlaying = false
                            withAnimation(.spring(duration: 0.6)) {
                                morphProgress = 0.0
                            }
                        } label: {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                Text("查看 NG 錯誤姿勢")
                            }
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(morphProgress < 0.5 ? Color.red.opacity(0.18) : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(morphProgress < 0.5 ? .red : .primary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(morphProgress < 0.5 ? Color.red : Color.clear, lineWidth: 2)
                            )
                        }

                        Button {
                            isAutoPlaying = false
                            withAnimation(.spring(duration: 0.6)) {
                                morphProgress = 1.0
                            }
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("查看標準黃金姿勢")
                            }
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(morphProgress >= 0.5 ? Color.green.opacity(0.18) : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(morphProgress >= 0.5 ? .green : .primary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(morphProgress >= 0.5 ? Color.green : Color.clear, lineWidth: 2)
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Side-by-side Detail Cards
                    VStack(spacing: 14) {
                        // Bad card
                        VStack(alignment: .leading, spacing: 8) {
                            Text(stage.mistakeContrast.badTitle)
                                .font(.headline)
                                .foregroundStyle(.red)
                            Text(stage.mistakeContrast.badDescription)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "bolt.trianglebadge.exclamationmark.fill")
                                    .foregroundStyle(.orange)
                                Text("後果：\(stage.mistakeContrast.badConsequence)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        }
                        .padding(16)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))

                        // Good card
                        VStack(alignment: .leading, spacing: 8) {
                            Text(stage.mistakeContrast.goodTitle)
                                .font(.headline)
                                .foregroundStyle(.green)
                            Text(stage.mistakeContrast.goodDescription)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "lightbulb.max.fill")
                                    .foregroundStyle(.yellow)
                                Text("教練秘訣：\(stage.mistakeContrast.proSecret)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        }
                        .padding(16)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)
            }
            .navigationTitle("姿勢訂正圖鑑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("開始實測") {
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}
