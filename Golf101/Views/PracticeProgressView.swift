import SwiftUI
import Charts

private struct FocusMovement: Identifiable {
    let id: String
    let title: String
    let cue: String
    let score: Double
}

private struct ChartDataPoint: Identifiable {
    let id: String
    let completedAt: Date
    let movementTitle: String
    let scorePercent: Double
}

private struct LegacyStageBarPoint: Identifiable {
    let id: Int
    let stageTitle: String
    let bestAccuracy: Double
    let themeColor: Color
}

struct PracticeProgressView: View {
    let history: [PracticeHistoryRecord]
    let stageRecords: [StageRecord]
    @State private var selectedStageID: GolfStageID = .setup

    private var sortedHistory: [PracticeHistoryRecord] {
        history.sorted { $0.completedAt < $1.completedAt }
    }

    private var latestAttempt: PracticeHistoryRecord? {
        sortedHistory.last
    }

    private var selectedStageHistory: [PracticeHistoryRecord] {
        sortedHistory.filter { $0.stageRawValue == selectedStageID.rawValue }
    }

    private var focusMovement: FocusMovement? {
        guard let latestAttempt,
              let lowest = PracticeHistoryRecord.lowestCheckpoint(in: latestAttempt.checkpointScores) else {
            return nil
        }
        return FocusMovement(
            id: lowest.id,
            title: lowest.title,
            cue: lowest.cue,
            score: lowest.scorePercent
        )
    }

    private var weakestLegacyStage: (title: String, score: Double)? {
        stageRecords
            .filter { $0.completedCount > 0 }
            .compactMap { record -> (String, Double)? in
                guard let stage = GolfStage.allStages.first(where: { $0.id == record.stageID }) else { return nil }
                return (stage.title, record.bestAccuracy)
            }
            .min { $0.1 < $1.1 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                summaryCard
                trajectoryCard
                focusCard
                tenMinuteCard
            }
            .padding(16)
        }
        .background(Color(red: 0.045, green: 0.09, blue: 0.11).ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear {
            selectedStageID = latestAttempt?.stageID ?? .setup
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.golf")
                .font(.title2.weight(.bold))
                .foregroundStyle(.mint)
                .frame(width: 46, height: 46)
                .background(.mint.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 3) {
                Text("\(history.count) 次關卡練習已納入軌跡")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text("每次完成關卡會記錄三個分解動作分數。")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }

    private var trajectoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                history.isEmpty ? "既有各關最佳分數" : "從本版開始的動作進步軌跡",
                systemImage: "chart.xyaxis.line"
            )
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)

            if !history.isEmpty {
                stagePickerBar
                selectedStageLineChartSection
            } else if !legacyStageBarPoints.isEmpty {
                legacyBestScoresBarChartSection
            } else {
                ContentUnavailableView(
                    "還沒有練習紀錄",
                    systemImage: "chart.xyaxis.line",
                    description: Text("完成第一個關卡後，這裡就會開始記錄動作分數。")
                )
                .frame(height: 190)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
    }

    private var stagePickerBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(GolfStage.allStages) { stage in
                    stageFilterButton(for: stage)
                }
            }
        }
    }

    private func stageFilterButton(for stage: GolfStage) -> some View {
        let isSelected = selectedStageID == stage.id
        let textColor: Color = isSelected ? .black : .white.opacity(0.78)
        let bgColor: Color = isSelected ? stage.themeColor : Color.white.opacity(0.10)

        return Button {
            selectedStageID = stage.id
        } label: {
            Text(stage.title)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .foregroundStyle(textColor)
                .background(bgColor, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var selectedStageLineChartSection: some View {
        if selectedStageHistory.isEmpty {
            ContentUnavailableView(
                "這一關還沒有新紀錄",
                systemImage: "chart.xyaxis.line",
                description: Text("完成這一關後，分解動作的趨勢就會顯示在這裡。")
            )
            .frame(height: 190)
        } else {
            Chart(flattenedStageChartPoints) { point in
                LineMark(
                    x: .value("日期", point.completedAt),
                    y: .value("動作分數", point.scorePercent),
                    series: .value("動作", point.movementTitle)
                )
                .foregroundStyle(by: .value("動作", point.movementTitle))
                .symbol(by: .value("動作", point.movementTitle))
            }
            .chartForegroundStyleScale(
                domain: chartMovementTitles,
                range: [Color.mint, Color.cyan, Color.yellow]
            )
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .chartLegend(position: .bottom, alignment: .leading, spacing: 8)
            .frame(height: 240)
            .accessibilityLabel("所選關卡三個分解動作每次完成時的分數折線圖")

            Text("每條線代表一個分解動作；每個點是該次完成時的分數。選擇其他關卡查看動作趨勢，縱軸為 0–100。")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.62))
        }
    }

    private var legacyBestScoresBarChartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Chart(legacyStageBarPoints) { item in
                BarMark(
                    x: .value("關卡", item.stageTitle),
                    y: .value("最佳分數", item.bestAccuracy)
                )
                .foregroundStyle(item.themeColor.gradient)
                .annotation(position: .top) {
                    Text("\(Int(item.bestAccuracy))")
                        .font(.caption2.monospacedDigit().bold())
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .chartYScale(domain: 0...100)
            .frame(height: 200)

            Text("舊版只保留各關累計次數、最佳分數與最近練習日期，沒有逐次動作分數；無法重建舊的折線。從本版開始累積完整軌跡。")
                .font(.caption)
                .foregroundStyle(.orange.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var focusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("本次建議加強", systemImage: "scope")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            if let focusMovement {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(focusMovement.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(Int(focusMovement.score)) 分")
                                .font(.caption.monospacedDigit().bold())
                                .foregroundStyle(.orange)
                        }
                        Text(focusMovement.cue)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.74))
                    }
                }
            } else if let weakestLegacyStage {
                Text("現有舊紀錄中，\(weakestLegacyStage.title) 的最佳分數最低（\(Int(weakestLegacyStage.score)) 分），建議先複習這一關。舊資料沒有細項動作分數，因此這是關卡層級的粗略提示。")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("完成一個關卡後，會依最近一次三個動作中分數最低的項目，提供下一次練習建議。")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(14)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.orange.opacity(0.28)))
    }

    private var tenMinuteCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("每日 10 分鐘怎麼安排", systemImage: "timer")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
            Text("目前每關有 3 個分解動作，每個動作只要求達標定格 2.2–3 秒；五關合計最低約 37 秒，這只是系統定格時間，不等於實際練習時間。")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)
            Text("建議以 5 次關卡通關作為 10 分鐘基準：完成一輪五關（15 個動作檢查），再把剩餘時間重練最低分關卡，熟悉後約可到 6–7 次。姿勢需要多次調整時，少於 5 次也合理。這是訓練安排建議，程式目前沒有量測整段耗時。通過數不是揮桿次數：每完成一關只加 1 次，尚未計算每個動作的反覆練習。")
                .font(.caption)
                .foregroundStyle(.mint.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
    }

    private var chartMovementTitles: [String] {
        PracticeHistoryRecord.orderedCheckpointIDs(for: selectedStageID)
            .map { PracticeHistoryRecord.movementDetails(for: $0).title }
    }

    private var flattenedStageChartPoints: [ChartDataPoint] {
        var points: [ChartDataPoint] = []
        for (recordIndex, record) in selectedStageHistory.enumerated() {
            let sortedKeys = record.checkpointScores.keys.sorted()
            for key in sortedKeys {
                guard let rawScore = record.checkpointScores[key] else { continue }
                let details = PracticeHistoryRecord.movementDetails(for: key)
                points.append(
                    ChartDataPoint(
                        id: "\(recordIndex)_\(key)",
                        completedAt: record.completedAt,
                        movementTitle: details.title,
                        scorePercent: min(100.0, max(0.0, rawScore * 100.0))
                    )
                )
            }
        }
        return points
    }

    private var legacyStageBarPoints: [LegacyStageBarPoint] {
        stageRecords
            .filter { $0.completedCount > 0 }
            .compactMap { record in
                guard let stage = GolfStage.allStages.first(where: { $0.id == record.stageID }) else { return nil }
                return LegacyStageBarPoint(
                    id: record.stageRawValue,
                    stageTitle: stage.title,
                    bestAccuracy: min(100.0, max(0.0, record.bestAccuracy)),
                    themeColor: stage.themeColor
                )
            }
    }
}
