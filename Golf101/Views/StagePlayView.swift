//
//  StagePlayView.swift
//  Golf101
//
//  Created by Golf101 AI Coach on 2026/10/23.
//

import SwiftUI
import AVFoundation
import Combine

private struct PracticeDrillStep: Identifiable {
    let checkpointID: String
    let title: String
    let cue: String

    var id: String { checkpointID }
}

struct StagePlayView: View {
    let stage: GolfStage
    @Bindable var profile: PlayerProfile
    let stageRecord: StageRecord?
    let onStageCompleted: (Int, Double, Bool, Int, [String: Double]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var poseDetector = VisionPoseDetector()
    @State private var isInteractiveSimulatorMode: Bool = false
    @State private var interactiveSkeleton: PoseSkeleton
    @State private var selectedPreset: SimulationPresetMode = .beginnerMistake
    @State private var currentDrillStepIndex: Int = 0
    @State private var completedDrillStepIDs: Set<String> = []
    @State private var completedDrillStepScores: [String: Double] = [:]

    // Hold timer state
    @State private var holdElapsed: Double = 0.0
    @State private var isStageCleared: Bool = false
    @State private var showComparisonSheet: Bool = false

    // Voice Coach (AVSpeechSynthesizer) so user can hear corrections from 2m away
    @State private var isVoiceCoachEnabled: Bool = true
    @State private var lastSpokenTip: String = ""
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    @State private var speechCommandListener = SpeechCommandListener()

    // Quiz state in victory modal
    @State private var selectedQuizOption: Int? = nil
    @State private var hasSubmittedQuiz: Bool = false
    @State private var hasClaimedReward: Bool = false

    private let holdTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    init(
        stage: GolfStage,
        profile: PlayerProfile,
        stageRecord: StageRecord?,
        onStageCompleted: @escaping (Int, Double, Bool, Int, [String: Double]) -> Void
    ) {
        self.stage = stage
        self.profile = profile
        self.stageRecord = stageRecord
        self.onStageCompleted = onStageCompleted
        _interactiveSkeleton = State(
            initialValue: PostureEvaluator.presetSkeleton(for: stage.id, mode: .beginnerMistake)
        )
    }

    private var activeSkeleton: PoseSkeleton {
        if !isInteractiveSimulatorMode, let live = poseDetector.detectedSkeleton, poseDetector.isHumanDetected {
            return live
        }
        return interactiveSkeleton
    }

    private var idealSkeleton: PoseSkeleton {
        PostureEvaluator.presetSkeleton(for: stage.id, mode: .idealPro)
    }

    private var evaluation: StageEvaluationSummary {
        PostureEvaluator.evaluate(
            skeleton: activeSkeleton,
            stageID: stage.id,
            gripStyle: profile.preferredGrip
        )
    }

    private var drillSteps: [PracticeDrillStep] {
        switch stage.id {
        case .setup:
            return [
                PracticeDrillStep(checkpointID: "setup_stance", title: "站穩底盤", cue: "雙腳張開約與肩同寬，腳掌平均踩穩。"),
                PracticeDrillStep(checkpointID: "setup_spine", title: "髖部前傾", cue: "從髖關節向前折，背部保持自然挺直。"),
                PracticeDrillStep(checkpointID: "setup_knee", title: "膝蓋留彈性", cue: "膝蓋微彎但不蹲低，重心留在足弓。")
            ]
        case .grip:
            return [
                PracticeDrillStep(checkpointID: "grip_v_angle", title: "對準虎口 V", cue: "雙手虎口自然指向右肩與下巴之間。"),
                PracticeDrillStep(checkpointID: "grip_connection", title: "連結雙手", cue: "依選定握法讓左右手靠攏，握力保持放鬆。"),
                PracticeDrillStep(checkpointID: "grip_triangle", title: "手臂成三角", cue: "肩膀放鬆，雙手自然垂在身體前方。")
            ]
        case .backswing:
            return [
                PracticeDrillStep(checkpointID: "backswing_coil", title: "胸口帶動啟動", cue: "先轉動胸口與肩膀，讓手臂跟著身體一起上桿。"),
                PracticeDrillStep(checkpointID: "backswing_arm", title: "上桿保持寬度", cue: "左手臂自然延伸，不要用手肘折起來抬桿。"),
                PracticeDrillStep(checkpointID: "backswing_sway", title: "頂點穩住下盤", cue: "右腳內側踩穩，骨盆轉動但不要往右滑。")
            ]
        case .impact:
            return [
                PracticeDrillStep(checkpointID: "impact_weight", title: "重心移向左腳", cue: "下桿先讓重心回到左腳，避免留在後腳撈球。"),
                PracticeDrillStep(checkpointID: "impact_lean", title: "雙手領先球位", cue: "擊球時手把略在球前，避免手腕提早翻開。"),
                PracticeDrillStep(checkpointID: "impact_head", title: "頭部保持穩定", cue: "重心前移時讓頭留在球後，不要跟著往前衝。")
            ]
        case .finish:
            return [
                PracticeDrillStep(checkpointID: "finish_balance", title: "站穩左腳", cue: "收桿時胸口轉向目標，重心穩定落在左腳。"),
                PracticeDrillStep(checkpointID: "finish_hands", title: "完成送桿收桿", cue: "順勢送出雙手，最後自然收在左肩上方。"),
                PracticeDrillStep(checkpointID: "finish_knee", title: "右膝自然靠攏", cue: "右腳跟抬起，以右腳尖輕點地面維持平衡。")
            ]
        }
    }

    private var currentDrillStep: PracticeDrillStep {
        let safeIndex = max(0, min(currentDrillStepIndex, drillSteps.count - 1))
        return drillSteps[safeIndex]
    }

    private var currentDrillCheckpoint: CheckpointResult {
        evaluation.checkpoints.first(where: { $0.id == currentDrillStep.checkpointID })
            ?? evaluation.checkpoints[0]
    }

    private var isCurrentDrillStepPassing: Bool {
        currentDrillCheckpoint.progress >= 0.86
    }

    private var isCameraPositionReady: Bool {
        poseDetector.isHumanDetected
            && evaluation.checkpoints.allSatisfy { $0.currentValueText != "偵測中" }
    }

    private var completedStageAccuracy: Double {
        guard !completedDrillStepScores.isEmpty else { return evaluation.overallAccuracy }
        let raw = completedDrillStepScores.values.reduce(0, +)
            / Double(completedDrillStepScores.count) * 100.0
        return min(100.0, max(0.0, raw))
    }

    private var currentDrillStepTip: String {
        isCurrentDrillStepPassing
            ? "這一步達標了，保持姿勢直到計時完成。"
            : currentDrillCheckpoint.correctionTip
    }

    private var currentDrillEvaluation: StageEvaluationSummary {
        StageEvaluationSummary(
            stageID: stage.id,
            checkpoints: [currentDrillCheckpoint],
            overallAccuracy: currentDrillCheckpoint.progress * 100.0,
            primaryCoachTip: currentDrillStepTip,
            isAllPassing: isCurrentDrillStepPassing
        )
    }

    private var holdProgress: Double {
        min(1.0, holdElapsed / max(0.5, stage.holdDurationRequired))
    }

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.09, blue: 0.13)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                // 1. Top Control Bar
                topControlBar

                // 2. Stage 2 Grip Selector (if stage == .grip)
                if stage.id == .grip {
                    gripStylePickerBar
                }

                practiceDrillCard

                // 3. Camera / Interactive Skeleton Viewport
                viewportSection

                // 4. Interactive Practice Controls (when in Simulator/Touch mode)
                if isInteractiveSimulatorMode {
                    interactiveTuningBar
                }

                // 5. Real-time 3 Checkpoints List
                checkpointsDashboard
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            // 6. Stage Cleared Celebration & Quiz Overlay
            if isStageCleared {
                victoryOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            poseDetector.requestPermissionAndStart()
            if poseDetector.authorizationState == .unavailable || poseDetector.authorizationState == .denied {
                isInteractiveSimulatorMode = true
            }
            speakCoachTipIfNeeded(currentDrillStepTip, force: true)
        }
        .onDisappear {
            poseDetector.stopSession()
            speechCommandListener.stop(status: "")
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        .onReceive(holdTimer) { _ in
            guard !isStageCleared else { return }
            let canAdvanceHold = isInteractiveSimulatorMode || poseDetector.isHumanDetected
            if canAdvanceHold && isCurrentDrillStepPassing {
                holdElapsed += 0.1
                if holdElapsed >= stage.holdDurationRequired {
                    completeCurrentDrillStep()
                }
            } else {
                holdElapsed = max(0.0, holdElapsed - 0.15)
            }
        }
        .onChange(of: currentDrillStepTip) { _, newTip in
            speakCoachTipIfNeeded(newTip, force: false)
        }
        .sheet(isPresented: $showComparisonSheet) {
            PostureComparisonSheet(stage: stage, gripStyle: profile.preferredGrip)
        }
    }

    // MARK: - Top Control Bar

    private var topControlBar: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.14), in: Circle())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(stage.chapterBadge)
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(stage.themeColor)
                Text(stage.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Spacer()

            // Voice Coach Toggle
            Button {
                isVoiceCoachEnabled.toggle()
                if !isVoiceCoachEnabled {
                    speechSynthesizer.stopSpeaking(at: .immediate)
                } else {
                    speakCoachTipIfNeeded(currentDrillStepTip, force: true)
                }
            } label: {
                Image(systemName: isVoiceCoachEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isVoiceCoachEnabled ? .yellow : .white.opacity(0.6))
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.12), in: Circle())
            }
            .accessibilityLabel("語音教練開關")

            // Mistake Comparison Guide Button
            Button {
                showComparisonSheet = true
            } label: {
                Label("對比圖鑑", systemImage: "person.2.gobackward")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(stage.themeColor.opacity(0.85), in: Capsule())
            }

            // Camera vs Interactive Mode Toggle
            Button {
                withAnimation(.spring(duration: 0.35)) {
                    isInteractiveSimulatorMode.toggle()
                    holdElapsed = 0
                }
            } label: {
                Label(
                    isInteractiveSimulatorMode ? "互動人偶" : "AI 鏡頭",
                    systemImage: isInteractiveSimulatorMode ? "hand.draw.fill" : "camera.viewfinder"
                )
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    isInteractiveSimulatorMode ? Color.indigo : Color.green.opacity(0.85),
                    in: Capsule()
                )
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Stage 2 Grip Picker Bar

    private var gripStylePickerBar: some View {
        HStack(spacing: 8) {
            Text("握桿流派：")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.8))

            ForEach(GripStyle.allCases) { style in
                let isSelected = profile.preferredGrip == style
                Button {
                    withAnimation {
                        profile.preferredGrip = style
                    }
                } label: {
                    Text(style.shortName)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            isSelected ? stage.themeColor : Color.white.opacity(0.12),
                            in: Capsule()
                        )
                        .foregroundStyle(.white)
                }
            }
            Spacer()
        }
    }

    private var practiceDrillCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("分解練習", systemImage: "figure.golf")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(stage.themeColor)
                Spacer()
                Text("第 \(currentDrillStepIndex + 1) / \(drillSteps.count) 步")
                    .font(.caption2.monospacedDigit().weight(.bold))
                    .foregroundStyle(.white.opacity(0.8))

                Button {
                    if speechCommandListener.isListening {
                        speechCommandListener.stop()
                    } else {
                        speechSynthesizer.stopSpeaking(at: .immediate)
                        Task {
                            await speechCommandListener.start(onCommand: executeVoiceCommand)
                        }
                    }
                } label: {
                    Label(
                        speechCommandListener.isListening ? "聆聽中" : "語音指令",
                        systemImage: speechCommandListener.isListening ? "waveform" : "mic.fill"
                    )
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(
                        speechCommandListener.isListening ? Color.red.opacity(0.85) : Color.white.opacity(0.12),
                        in: Capsule()
                    )
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(speechCommandListener.isListening ? "停止語音聆聽" : "開始語音指令")
            }

            HStack(spacing: 6) {
                ForEach(drillSteps.indices, id: \.self) { index in
                    let step = drillSteps[index]
                    let isCompleted = completedDrillStepIDs.contains(step.id)
                    let isCurrent = index == currentDrillStepIndex

                    Button {
                        guard index <= currentDrillStepIndex else { return }
                        withAnimation(.spring(duration: 0.28)) {
                            currentDrillStepIndex = index
                            holdElapsed = 0
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 11, weight: .bold))
                            Text(step.title)
                                .font(.system(size: 10, weight: .bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 7)
                        .background(
                            isCurrent ? stage.themeColor.opacity(0.82) : Color.white.opacity(isCompleted ? 0.12 : 0.06),
                            in: Capsule()
                        )
                        .foregroundStyle(isCurrent ? .white : .white.opacity(isCompleted ? 0.8 : 0.5))
                    }
                    .buttonStyle(.plain)
                    .disabled(index > currentDrillStepIndex)
                    .accessibilityLabel("第 \(index + 1) 步：\(step.title)")
                    .accessibilityAddTraits(isCurrent ? .isSelected : [])
                }
            }

            HStack(alignment: .top, spacing: 7) {
                Image(systemName: isCurrentDrillStepPassing ? "checkmark.circle.fill" : "lightbulb.fill")
                    .foregroundStyle(isCurrentDrillStepPassing ? .green : .yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text(currentDrillStep.title)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.white)
                    Text(currentDrillStep.cue)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(speechCommandListener.statusMessage)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(speechCommandListener.isListening ? .mint : .white.opacity(0.52))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(stage.themeColor.opacity(0.28), lineWidth: 1)
        )
    }

    // MARK: - Main Camera / Skeleton Viewport

    private var viewportSection: some View {
        VStack(spacing: 0) {
            // Top Status Bar (Dedicated non-overlapping header inside viewport card)
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 3.5)
                            .frame(width: 30, height: 30)
                        Circle()
                            .trim(from: 0, to: currentDrillCheckpoint.progress)
                            .stroke(
                                isCurrentDrillStepPassing ? Color.green : Color.orange,
                                style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 30, height: 30)
                        Text("\(Int(currentDrillCheckpoint.progress * 100))")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Text("本步吻合度")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.70))
                        Text(isCurrentDrillStepPassing ? "本步達標！" : "調整中...")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(isCurrentDrillStepPassing ? .green : .orange)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    if !isInteractiveSimulatorMode && poseDetector.isCameraRunning {
                        Button {
                            poseDetector.toggleCameraPosition()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(7)
                                .background(Color.white.opacity(0.14), in: Circle())
                        }
                    }

                    // Hold Progress Ring
                    HStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.25), lineWidth: 3.5)
                                .frame(width: 28, height: 28)
                            Circle()
                                .trim(from: 0, to: holdProgress)
                                .stroke(Color.green, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 28, height: 28)
                            Image(systemName: isCurrentDrillStepPassing ? "timer" : "lock.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(isCurrentDrillStepPassing ? .green : .white.opacity(0.7))
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            Text("定格維持")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.70))
                            Text(String(format: "%.1f / %.1fs", holdElapsed, stage.holdDurationRequired))
                                .font(.caption.monospacedDigit().weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.45))

            // Middle Dedicated Canvas Area (Character & Swing Arc never overlapped by HUD bars)
            ZStack {
                if !isInteractiveSimulatorMode && poseDetector.isCameraRunning {
                    CameraPreviewRepresentable(session: poseDetector.captureSession)
                        .overlay(Color.black.opacity(0.25))
                }

                SkeletonOverlayView(
                    stageID: stage.id,
                    currentSkeleton: Binding(
                        get: { activeSkeleton },
                        set: { updated in
                            interactiveSkeleton = updated
                        }
                    ),
                    idealSkeleton: idealSkeleton,
                    evaluation: currentDrillEvaluation,
                    isInteractiveMode: isInteractiveSimulatorMode,
                    onJointDragged: {
                        profile.totalCorrectionsCount += 1
                    }
                )

                // If in Camera Mode and no body detected yet, show compact bottom banner
                if !isInteractiveSimulatorMode && !poseDetector.isHumanDetected {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "person.crop.rectangle")
                                .foregroundStyle(.yellow)
                            Text(
                                poseDetector.isCameraRunning
                                    ? "請退後約 2 公尺讓全身入鏡..."
                                    : "模擬器無實體鏡頭，可切換互動人偶"
                            )
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)

                            Spacer()

                            Button {
                                withAnimation {
                                    isInteractiveSimulatorMode = true
                                }
                            } label: {
                                Text("切換互動人偶")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.yellow, in: Capsule())
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.black.opacity(0.78), in: Capsule())
                        .padding(.horizontal, 12)
                        .padding(.bottom, 6)
                    }
                } else if !isInteractiveSimulatorMode {
                    VStack {
                        Spacer()
                        Label(
                            isCameraPositionReady
                                ? "定位完成：已偵測到本關所需姿勢，可以開始"
                                : "已偵測到人形，請調整距離與站位，讓關節完整入鏡",
                            systemImage: isCameraPositionReady ? "checkmark.circle.fill" : "viewfinder"
                        )
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            (isCameraPositionReady ? Color.green : Color.orange).opacity(0.88),
                            in: Capsule()
                        )
                        .padding(.bottom, 8)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Bottom Dedicated Coach Feedback Bar (Non-overlapping with golfer feet & ball)
            HStack(alignment: .center, spacing: 10) {
                Circle()
                    .fill(isCurrentDrillStepPassing ? Color.green : Color(red: 1.0, green: 0.23, blue: 0.36))
                    .frame(width: 9, height: 9)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("AI 高球教練即時指導")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(isCurrentDrillStepPassing ? .green : .yellow)
                        if isInteractiveSimulatorMode {
                            Text("• 可直接拖曳白色支點或點選下方預設姿勢")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.65))
                        }
                    }
                    Text(currentDrillStepTip)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color.black.opacity(0.65))
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.07, blue: 0.11),
                    Color(red: 0.08, green: 0.12, blue: 0.18),
                    Color(red: 0.05, green: 0.08, blue: 0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .frame(maxHeight: .infinity)
    }

    // MARK: - Interactive Simulator Tuning Bar

    private var interactiveTuningBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(SimulationPresetMode.allCases) { mode in
                    let isSelected = selectedPreset == mode
                    Button {
                        withAnimation(.spring(duration: 0.45)) {
                            selectedPreset = mode
                            interactiveSkeleton = PostureEvaluator.presetSkeleton(for: stage.id, mode: mode)
                            holdElapsed = 0
                            profile.totalCorrectionsCount += 1
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: iconForPreset(mode))
                            Text(mode.rawValue)
                        }
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            isSelected ? colorForPreset(mode) : Color.white.opacity(0.10),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .foregroundStyle(.white)
                    }
                }
            }

            // Extra fine-tuning slider for Stage 2 Grip V-Groove Angle
            if stage.id == .grip {
                HStack(spacing: 10) {
                    Text("虎口 V 字角度微調")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.85))
                    Slider(
                        value: Binding(
                            get: { interactiveSkeleton.detectedGripVAngle },
                            set: { newVal in
                                interactiveSkeleton.detectedGripVAngle = newVal
                                interactiveSkeleton.handConnectionScore = max(0.86, interactiveSkeleton.handConnectionScore)
                            }
                        ),
                        in: -15...45,
                        step: 1
                    )
                    .tint(stage.themeColor)
                    Text("\(Int(interactiveSkeleton.detectedGripVAngle))°")
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, alignment: .trailing)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Real-time 3 Checkpoints Dashboard

    private var checkpointsDashboard: some View {
        VStack(spacing: 6) {
            ForEach(evaluation.checkpoints) { item in
                let isCompleted = completedDrillStepIDs.contains(item.id)
                let isCurrent = currentDrillStep.id == item.id
                let displayedProgress = isCompleted ? 1.0 : item.progress

                HStack(spacing: 10) {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : item.status.iconName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(isCompleted ? .green : item.status.color)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(item.title)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                            Spacer()
                            Text(isCompleted ? "本步已達標" : "目前：\(item.currentValueText)")
                                .font(.caption.monospacedDigit().weight(.bold))
                                .foregroundStyle(isCompleted ? .green : item.status.color)
                            Text("/ 目標 \(item.targetValueText)")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.6))
                        }

                        GeometryReader { barGeo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.14))
                                Capsule()
                                    .fill((isCompleted ? Color.green : item.status.color).gradient)
                                    .frame(width: barGeo.size.width * max(0.0, min(1.0, displayedProgress)))
                            }
                        }
                        .frame(height: 6)
                    }

                    Text(isCompleted ? "已完成" : (isCurrent ? "本步" : item.status.badgeText))
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((isCompleted ? Color.green : (isCurrent ? stage.themeColor : item.status.color)).opacity(0.85), in: Capsule())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    (isCurrent ? stage.themeColor.opacity(0.12) : Color.white.opacity(0.08)),
                    in: RoundedRectangle(cornerRadius: 14)
                )
            }
        }
    }

    // MARK: - Stage Victory & Quiz Bonus Overlay

    private var victoryOverlay: some View {
        let earnedStars = starsForAccuracy(completedStageAccuracy)
        let quizCorrect = selectedQuizOption == stage.quiz.correctIndex
        let totalXP = stage.xpReward + (hasSubmittedQuiz && quizCorrect ? 50 : 0)

        return ZStack {
            Color.black.opacity(0.78)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    // Trophy & Stars
                    VStack(spacing: 8) {
                        Text("STAGE CLEAR!")
                            .font(.caption.weight(.black))
                            .tracking(2)
                            .foregroundStyle(.yellow)

                        Text("🎉 恭喜通過「\(stage.title)」！")
                            .font(.title3.weight(.heavy))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 12) {
                            ForEach(1...3, id: \.self) { index in
                                Image(systemName: index <= earnedStars ? "star.fill" : "star")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundStyle(index <= earnedStars ? .yellow : .white.opacity(0.25))
                                    .shadow(color: index <= earnedStars ? .orange.opacity(0.7) : .clear, radius: 8)
                            }
                        }
                        .padding(.vertical, 4)

                        HStack(spacing: 16) {
                            Label("精準度 \(Int(completedStageAccuracy))%", systemImage: "scope")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.green)

                            Label("+\(totalXP) XP", systemImage: "sparkles")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.yellow)
                        }
                    }

                    Divider()
                        .background(.white.opacity(0.2))

                    // Bonus Concept Quiz
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("教練觀念加分題 (+50 XP)", systemImage: "brain.head.profile")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.cyan)
                            Spacer()
                            if hasSubmittedQuiz {
                                Text(quizCorrect ? "✅ 答對了！+50 XP" : "💡 記住這個小秘訣！")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(quizCorrect ? .green : .orange)
                            }
                        }

                        Text(stage.quiz.question)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)

                        ForEach(Array(stage.quiz.options.enumerated()), id: \.offset) { idx, optionText in
                            let isChosen = selectedQuizOption == idx
                            let isRightAnswer = idx == stage.quiz.correctIndex
                            Button {
                                guard !hasSubmittedQuiz else { return }
                                selectedQuizOption = idx
                                withAnimation {
                                    hasSubmittedQuiz = true
                                }
                            } label: {
                                HStack {
                                    Text(optionText)
                                        .font(.caption.weight(.semibold))
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    if hasSubmittedQuiz {
                                        if isRightAnswer {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.green)
                                        } else if isChosen {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.red)
                                        }
                                    }
                                }
                                .padding(12)
                                .background(
                                    quizOptionBackground(isChosen: isChosen, isRightAnswer: isRightAnswer),
                                    in: RoundedRectangle(cornerRadius: 12)
                                )
                                .foregroundStyle(.white)
                            }
                            .disabled(hasSubmittedQuiz)
                        }

                        if hasSubmittedQuiz {
                            Text("💡 解析：\(stage.quiz.explanation)")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.9))
                                .padding(10)
                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))

                    // Action Buttons
                    HStack(spacing: 12) {
                        Button {
                            withAnimation {
                                isStageCleared = false
                                holdElapsed = 0
                                currentDrillStepIndex = 0
                                completedDrillStepIDs = []
                                completedDrillStepScores = [:]
                                selectedQuizOption = nil
                                hasSubmittedQuiz = false
                                hasClaimedReward = false
                                selectedPreset = .beginnerMistake
                                interactiveSkeleton = PostureEvaluator.presetSkeleton(for: stage.id, mode: .beginnerMistake)
                            }
                        } label: {
                            Label("再練一次", systemImage: "arrow.counterclockwise")
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
                                .foregroundStyle(.white)
                        }

                        Button {
                            guard !hasClaimedReward else { return }
                            hasClaimedReward = true
                            onStageCompleted(
                                earnedStars,
                                completedStageAccuracy,
                                hasSubmittedQuiz && quizCorrect,
                                totalXP,
                                completedDrillStepScores
                            )
                            dismiss()
                        } label: {
                            Label("領取獎勵並返回地圖", systemImage: "flag.checkered")
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(stage.themeColor.gradient, in: RoundedRectangle(cornerRadius: 16))
                                .foregroundStyle(.white)
                        }
                        .disabled(hasClaimedReward)
                    }
                }
                .padding(22)
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color(red: 0.10, green: 0.15, blue: 0.22))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(stage.themeColor.opacity(0.6), lineWidth: 2)
                        )
                )
                .padding(16)
            }
        }
    }

    // MARK: - Helpers

    private func completeCurrentDrillStep() {
        completedDrillStepIDs.insert(currentDrillStep.id)
        completedDrillStepScores[currentDrillStep.id] = currentDrillCheckpoint.progress

        if currentDrillStepIndex + 1 < drillSteps.count {
            if speechCommandListener.isListening {
                speechCommandListener.stop(status: "已完成本步，進入下一步")
            }
            withAnimation(.spring(duration: 0.35)) {
                currentDrillStepIndex += 1
                holdElapsed = 0
            }
            speakCoachTipIfNeeded("下一步：\(currentDrillStep.title)。\(currentDrillStep.cue)", force: true)
        } else {
            triggerStageClear()
        }
    }

    private func executeVoiceCommand(_ command: SpeechCommand) {
        switch command {
        case .next:
            guard isCurrentDrillStepPassing else {
                speakCoachTipIfNeeded("目前這一步還沒達標，請先依照畫面提示調整姿勢。", force: true)
                return
            }
            let remaining = max(0, stage.holdDurationRequired - holdElapsed)
            speakCoachTipIfNeeded(
                "這一步已達標，請再穩定保持約 \(Int(ceil(remaining))) 秒，達到定格時間後會自動進入下一步。",
                force: true
            )

        case .repeatTip:
            speakCoachTipIfNeeded(
                "第 \(currentDrillStepIndex + 1) 步，\(currentDrillStep.title)。\(currentDrillStep.cue)。\(currentDrillStepTip)",
                force: true
            )

        case .restartStep:
            completedDrillStepIDs.remove(currentDrillStep.id)
            completedDrillStepScores.removeValue(forKey: currentDrillStep.id)
            holdElapsed = 0
            speakCoachTipIfNeeded("已重置目前步驟。\(currentDrillStep.title)：\(currentDrillStep.cue)", force: true)

        case .help:
            speakCoachTipIfNeeded("你可以說：下一步、再說一次、重來，或語音指令。", force: true)
        }
    }

    private func triggerStageClear() {
        if speechCommandListener.isListening {
            speechCommandListener.stop(status: "恭喜過關，已結束語音聆聽")
        }
        withAnimation(.spring(duration: 0.5)) {
            isStageCleared = true
        }
        speakCoachTipIfNeeded("太棒了！動作非常標準，恭喜過關！", force: true)
    }

    private func starsForAccuracy(_ accuracy: Double) -> Int {
        if accuracy >= 92.0 { return 3 }
        if accuracy >= 84.0 { return 2 }
        return 1
    }

    private func iconForPreset(_ mode: SimulationPresetMode) -> String {
        switch mode {
        case .beginnerMistake: return "exclamationmark.triangle.fill"
        case .almostThere: return "slider.horizontal.3"
        case .idealPro: return "checkmark.seal.fill"
        }
    }

    private func colorForPreset(_ mode: SimulationPresetMode) -> Color {
        switch mode {
        case .beginnerMistake: return .red.opacity(0.85)
        case .almostThere: return .orange.opacity(0.85)
        case .idealPro: return .green.opacity(0.85)
        }
    }

    private func quizOptionBackground(isChosen: Bool, isRightAnswer: Bool) -> Color {
        guard hasSubmittedQuiz else {
            return isChosen ? stage.themeColor.opacity(0.5) : Color.white.opacity(0.10)
        }
        if isRightAnswer {
            return Color.green.opacity(0.35)
        }
        if isChosen {
            return Color.red.opacity(0.35)
        }
        return Color.white.opacity(0.06)
    }

    private func speakCoachTipIfNeeded(_ text: String, force: Bool) {
        guard isVoiceCoachEnabled, !speechCommandListener.isListening else { return }
        if !force && text == lastSpokenTip { return }
        lastSpokenTip = text
        speechSynthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-TW")
        utterance.rate = 0.51
        utterance.pitchMultiplier = 1.05
        speechSynthesizer.speak(utterance)
    }
}
