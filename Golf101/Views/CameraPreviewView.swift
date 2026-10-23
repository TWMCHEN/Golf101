//
//  CameraPreviewView.swift
//  Golf101
//
//  Created by Golf101 AI Coach on 2026/10/23.
//

import SwiftUI
import AVFoundation

// MARK: - UIKit AVCaptureVideoPreviewLayer Wrapper

struct CameraPreviewRepresentable: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewLayerView {
        let view = PreviewLayerView()
        view.videoPreviewLayer?.session = session
        view.videoPreviewLayer?.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewLayerView, context: Context) {
        if uiView.videoPreviewLayer?.session !== session {
            uiView.videoPreviewLayer?.session = session
        }
    }

    final class PreviewLayerView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var videoPreviewLayer: AVCaptureVideoPreviewLayer? {
            layer as? AVCaptureVideoPreviewLayer
        }
    }
}

// MARK: - Biomechanical Mannequin & Kinematic Skeleton Overlay (SwingDecoded Style)

struct SkeletonOverlayView: View {
    let stageID: GolfStageID
    @Binding var currentSkeleton: PoseSkeleton
    let idealSkeleton: PoseSkeleton
    let evaluation: StageEvaluationSummary
    let isInteractiveMode: Bool
    var onJointDragged: (() -> Void)? = nil

    @State private var activeDraggedJoint: SkeletonJoint? = nil

    /// Character scale factor: fills the dedicated canvas prominently while keeping outer margin room for callouts
    private let figureScale: CGFloat = 0.90
    private let figureCenterYOffset: CGFloat = 0.01

    /// Precise kinematic bone connections matching the biomechanical reference
    private static let kinematicConnections: [(SkeletonJoint, SkeletonJoint)] = [
        (.nose, .neck),
        (.neck, .leftShoulder),
        (.neck, .rightShoulder),
        (.neck, .root),
        (.leftHip, .root),
        (.rightHip, .root),
        (.leftShoulder, .leftElbow),
        (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow),
        (.rightElbow, .rightWrist),
        (.leftHip, .leftKnee),
        (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee),
        (.rightKnee, .rightAnkle)
    ]

    private var problemJoints: Set<SkeletonJoint> {
        var set = Set<SkeletonJoint>()
        for cp in evaluation.checkpoints where cp.status != .perfect {
            for j in cp.highlightedJoints {
                set.insert(j)
            }
        }
        return set
    }

    /// Maps normalized (0...1) skeleton coordinates into a centered, scaled safe zone inside the canvas
    private func project(_ normPt: CGPoint, in size: CGSize) -> CGPoint {
        let sx = 0.50 + (normPt.x - 0.50) * figureScale
        let sy = (0.50 + figureCenterYOffset) + (normPt.y - 0.52) * figureScale
        return CGPoint(x: sx * size.width, y: sy * size.height)
    }

    /// Inverse mapping from screen touch location back to normalized (0...1) skeleton coordinates
    private func unproject(_ screenPt: CGPoint, in size: CGSize) -> CGPoint {
        let sx = screenPt.x / max(1, size.width)
        let sy = screenPt.y / max(1, size.height)
        let nx = 0.50 + (sx - 0.50) / figureScale
        let ny = 0.52 + (sy - (0.50 + figureCenterYOffset)) / figureScale
        return CGPoint(
            x: min(0.90, max(0.10, nx)),
            y: min(0.90, max(0.12, ny))
        )
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                // 1. Studio Ground Line, Swing Arc & Golf Ball Pivot
                swingArcAndGroundLayer(size: size)

                // 2. Ideal Target Ghost Mannequin & Club (Translucent Emerald Green Silhouette)
                mannequinLayer(
                    skeleton: idealSkeleton,
                    size: size,
                    isGhostIdeal: true
                )

                // 3. Current Volumetric Dark-Slate Mannequin Body + Metallic Golf Club
                mannequinLayer(
                    skeleton: currentSkeleton,
                    size: size,
                    isGhostIdeal: false
                )

                // 4. Crisp White Inner Kinematic Skeleton & Hollow Ring Nodes
                kinematicSkeletonAndNodesLayer(size: size)

                // 5. Diagnostic Callout Boxes positioned in non-overlapping outer margins
                diagnosticCalloutsLayer(size: size)
            }
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("高爾夫生物力學骨架檢視區")
            .accessibilityValue("目前姿勢吻合度 \(Int(evaluation.overallAccuracy))%")
            .accessibilityIdentifier("SkeletonOverlayCanvas")
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        guard isInteractiveMode else { return }
                        let normalizedPt = unproject(value.location, in: size)
                        if activeDraggedJoint == nil {
                            activeDraggedJoint = nearestJoint(to: normalizedPt, in: currentSkeleton)
                        }
                        if let joint = activeDraggedJoint {
                            currentSkeleton.joints[joint] = normalizedPt
                            onJointDragged?()
                        }
                    }
                    .onEnded { _ in
                        activeDraggedJoint = nil
                    }
            )
        }
    }

    // MARK: - 1. Swing Arc, Radial Vignette & Ground Ball

    private func swingArcAndGroundLayer(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let groundPt = project(CGPoint(x: 0.50, y: 0.855), in: canvasSize)
            let groundY = groundPt.y
            let center = project(CGPoint(x: 0.50, y: 0.50), in: canvasSize)
            let radius = min(w, h) * 0.37

            // Subtle glowing swing plane circle / arc
            var fullArc = Path()
            fullArc.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(105),
                endAngle: .degrees(355),
                clockwise: false
            )
            context.stroke(
                fullArc,
                with: .color(Color.cyan.opacity(0.20)),
                style: StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [4, 4])
            )

            // Highlighted upper swing arc (Cyan -> Emerald glow like reference)
            var topArc = Path()
            topArc.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(205),
                endAngle: .degrees(335),
                clockwise: false
            )
            context.stroke(
                topArc,
                with: .color(Color.cyan.opacity(0.26)),
                style: StrokeStyle(lineWidth: 6.0, lineCap: .round)
            )
            context.stroke(
                topArc,
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.25, green: 0.82, blue: 0.98),
                        Color(red: 0.20, green: 0.88, blue: 0.52),
                        Color(red: 0.25, green: 0.82, blue: 0.98)
                    ]),
                    startPoint: CGPoint(x: center.x - radius, y: center.y - radius * 0.6),
                    endPoint: CGPoint(x: center.x + radius, y: center.y - radius * 0.6)
                ),
                style: StrokeStyle(lineWidth: 2.6, lineCap: .round)
            )

            // Ground horizon shadow line
            var groundLine = Path()
            groundLine.move(to: CGPoint(x: w * 0.14, y: groundY))
            groundLine.addLine(to: CGPoint(x: w * 0.86, y: groundY))
            context.stroke(
                groundLine,
                with: .color(Color.white.opacity(0.14)),
                style: StrokeStyle(lineWidth: 1.4)
            )

            // Golf Ball Pivot Node on Ground Center
            let glowRect = CGRect(x: groundPt.x - 7, y: groundPt.y - 7, width: 14, height: 14)
            context.fill(Path(ellipseIn: glowRect), with: .color(Color.white.opacity(0.22)))

            let ballRect = CGRect(x: groundPt.x - 4.5, y: groundPt.y - 4.5, width: 9, height: 9)
            context.fill(Path(ellipseIn: ballRect), with: .color(.white))
            context.stroke(Path(ellipseIn: ballRect), with: .color(Color.gray.opacity(0.6)), lineWidth: 1.2)
        }
    }

    // MARK: - 2 & 3. Volumetric Anatomical Mannequin & Golf Club

    private func mannequinLayer(skeleton: PoseSkeleton, size: CGSize, isGhostIdeal: Bool) -> some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let unit = min(w, h) * figureScale

            func pt(_ j: SkeletonJoint) -> CGPoint? {
                guard let norm = skeleton.joints[j] else { return nil }
                return project(norm, in: canvasSize)
            }

            let bodyFill: Color = isGhostIdeal
                ? Color(red: 0.16, green: 0.65, blue: 0.38).opacity(0.17)
                : Color(red: 0.16, green: 0.20, blue: 0.26).opacity(0.84)

            let bodyStroke: Color = isGhostIdeal
                ? Color(red: 0.25, green: 0.85, blue: 0.50).opacity(0.36)
                : Color(red: 0.52, green: 0.58, blue: 0.68).opacity(0.62)

            func drawLimbCapsule(from a: CGPoint?, to b: CGPoint?, thickness: CGFloat) {
                guard let a, let b else { return }
                var path = Path()
                path.move(to: a)
                path.addLine(to: b)
                context.stroke(
                    path,
                    with: .color(bodyStroke),
                    style: StrokeStyle(lineWidth: thickness + 2.4, lineCap: .round)
                )
                context.stroke(
                    path,
                    with: .color(bodyFill),
                    style: StrokeStyle(lineWidth: thickness, lineCap: .round)
                )
            }

            // A. Torso & Pelvis Volumetric Silhouette (Tapered V-shape waist, slim hips)
            if let lS = pt(.leftShoulder), let rS = pt(.rightShoulder),
               let lH = pt(.leftHip), let rH = pt(.rightHip) {
                var torso = Path()
                let shoulderExpand: CGFloat = unit * 0.016
                let hipExpand: CGFloat = unit * 0.006
                torso.move(to: CGPoint(x: lS.x - shoulderExpand, y: lS.y))
                torso.addLine(to: CGPoint(x: rS.x + shoulderExpand, y: rS.y))
                torso.addLine(to: CGPoint(x: rH.x + hipExpand, y: rH.y))
                torso.addLine(to: CGPoint(x: lH.x - hipExpand, y: lH.y))
                torso.closeSubpath()

                context.fill(torso, with: .color(bodyFill))
                context.stroke(
                    torso,
                    with: .color(bodyStroke),
                    style: StrokeStyle(lineWidth: 1.5, lineJoin: .round)
                )

                drawLimbCapsule(from: lH, to: rH, thickness: unit * 0.036)
            }

            // B. Legs & Shoes (Sleek athletic proportions matching reference)
            let thighWidth = max(9.5, unit * 0.036)
            let calfWidth = max(7.5, unit * 0.027)
            drawLimbCapsule(from: pt(.leftHip), to: pt(.leftKnee), thickness: thighWidth)
            drawLimbCapsule(from: pt(.leftKnee), to: pt(.leftAnkle), thickness: calfWidth)
            drawLimbCapsule(from: pt(.rightHip), to: pt(.rightKnee), thickness: thighWidth)
            drawLimbCapsule(from: pt(.rightKnee), to: pt(.rightAnkle), thickness: calfWidth)

            for ankleJoint in [SkeletonJoint.leftAnkle, .rightAnkle] {
                if let aPt = pt(ankleJoint) {
                    let shoeRect = CGRect(x: aPt.x - 7.5, y: aPt.y - 4.0, width: 15, height: 10)
                    let shoePath = Path(roundedRect: shoeRect, cornerRadius: 5.0)
                    context.fill(shoePath, with: .color(bodyFill))
                    context.stroke(shoePath, with: .color(bodyStroke), lineWidth: 1.4)
                }
            }

            // C. Head Silhouette with Visor Contour
            if let nosePt = pt(.nose) {
                let headW = max(22.0, unit * 0.088)
                let headH = headW * 1.18
                let headRect = CGRect(
                    x: nosePt.x - headW / 2.0,
                    y: nosePt.y - headH * 0.52,
                    width: headW,
                    height: headH
                )
                let headPath = Path(ellipseIn: headRect)
                context.fill(headPath, with: .color(bodyFill))
                context.stroke(headPath, with: .color(bodyStroke), lineWidth: 1.7)

                var visorArc = Path()
                visorArc.move(to: CGPoint(x: headRect.minX + 3, y: nosePt.y - 1.5))
                visorArc.addQuadCurve(
                    to: CGPoint(x: headRect.maxX - 3, y: nosePt.y - 1.5),
                    control: CGPoint(x: nosePt.x, y: nosePt.y + 4.5)
                )
                context.stroke(visorArc, with: .color(bodyStroke.opacity(0.8)), lineWidth: 1.3)
            }

            // D. Upper Arms & Forearms
            let upperArmWidth = max(10.0, unit * 0.040)
            let forearmWidth = max(8.5, unit * 0.033)
            drawLimbCapsule(from: pt(.rightShoulder), to: pt(.rightElbow), thickness: upperArmWidth)
            drawLimbCapsule(from: pt(.rightElbow), to: pt(.rightWrist), thickness: forearmWidth)
            drawLimbCapsule(from: pt(.leftShoulder), to: pt(.leftElbow), thickness: upperArmWidth)
            drawLimbCapsule(from: pt(.leftElbow), to: pt(.leftWrist), thickness: forearmWidth)

            // E. Golf Club (Grip + Tapered Metallic Shaft + Iron Clubhead Blade)
            if let lW = pt(.leftWrist), let rW = pt(.rightWrist) {
                let handsPt = CGPoint(x: (lW.x + rW.x) / 2.0, y: (lW.y + rW.y) / 2.0)
                let clubHeadPt = computeClubHeadPoint(
                    handsPt: handsPt,
                    skeleton: skeleton,
                    canvasSize: canvasSize,
                    isIdeal: isGhostIdeal
                )

                var shaft = Path()
                shaft.move(to: handsPt)
                shaft.addLine(to: clubHeadPt)
                let shaftColor: Color = isGhostIdeal
                    ? Color(red: 0.25, green: 0.85, blue: 0.50).opacity(0.42)
                    : Color(red: 0.82, green: 0.86, blue: 0.92)

                context.stroke(
                    shaft,
                    with: .color(shaftColor),
                    style: StrokeStyle(lineWidth: isGhostIdeal ? 2.8 : 3.4, lineCap: .round)
                )

                let angle = atan2(clubHeadPt.y - handsPt.y, clubHeadPt.x - handsPt.x)
                context.drawLayer { layerCtx in
                    layerCtx.translateBy(x: clubHeadPt.x, y: clubHeadPt.y)
                    layerCtx.rotate(by: Angle(radians: Double(angle)))

                    var blade = Path()
                    blade.move(to: CGPoint(x: -3, y: -2.5))
                    blade.addLine(to: CGPoint(x: 13, y: -5))
                    blade.addQuadCurve(to: CGPoint(x: 15, y: 5), control: CGPoint(x: 17, y: 0))
                    blade.addLine(to: CGPoint(x: -1.5, y: 3.5))
                    blade.closeSubpath()

                    layerCtx.fill(
                        blade,
                        with: .color(isGhostIdeal ? Color.green.opacity(0.35) : Color(red: 0.75, green: 0.80, blue: 0.86))
                    )
                    layerCtx.stroke(
                        blade,
                        with: .color(isGhostIdeal ? Color.green.opacity(0.55) : Color.white.opacity(0.85)),
                        lineWidth: 1.2
                    )
                }

                // Stage 2 V-Groove laser ray
                if !isGhostIdeal && stageID == .grip {
                    let rad = skeleton.detectedGripVAngle * .pi / 180.0
                    let rayLen = h * 0.20
                    let rayEnd = CGPoint(
                        x: handsPt.x + CGFloat(sin(rad)) * rayLen,
                        y: handsPt.y - CGFloat(cos(rad)) * rayLen
                    )
                    var laser = Path()
                    laser.move(to: handsPt)
                    laser.addLine(to: rayEnd)
                    let vGood = (12.0...30.0).contains(skeleton.detectedGripVAngle)
                    context.stroke(
                        laser,
                        with: .color(vGood ? Color.green : Color(red: 1.0, green: 0.23, blue: 0.36)),
                        style: StrokeStyle(lineWidth: 2.4, lineCap: .round, dash: [5, 4])
                    )
                }
            }
        }
    }

    // MARK: - 4. Crisp White Inner Kinematic Skeleton & Hollow Ring Nodes

    private func kinematicSkeletonAndNodesLayer(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            func pt(_ j: SkeletonJoint) -> CGPoint? {
                guard let norm = currentSkeleton.joints[j] else { return nil }
                return project(norm, in: canvasSize)
            }

            // A. Crisp White Inner Kinematic Linkage Lines
            for (jointA, jointB) in Self.kinematicConnections {
                guard let p1 = pt(jointA), let p2 = pt(jointB) else { continue }
                var link = Path()
                link.move(to: p1)
                link.addLine(to: p2)

                context.stroke(
                    link,
                    with: .color(Color.white.opacity(0.92)),
                    style: StrokeStyle(lineWidth: 1.9, lineCap: .round)
                )
            }

            // B. Problem Joint Target Highlight Rings (Compact so they don't crowd adjacent joints)
            if let primaryBadJoint = problemJoints.first, let p = pt(primaryBadJoint) {
                let ringRadius: CGFloat = 15.0
                let ringRect = CGRect(
                    x: p.x - ringRadius,
                    y: p.y - ringRadius,
                    width: ringRadius * 2,
                    height: ringRadius * 2
                )
                context.stroke(
                    Path(ellipseIn: ringRect),
                    with: .color(Color(red: 1.0, green: 0.23, blue: 0.36).opacity(0.28)),
                    lineWidth: 4.5
                )
                context.stroke(
                    Path(ellipseIn: ringRect),
                    with: .color(Color(red: 1.0, green: 0.23, blue: 0.36).opacity(0.92)),
                    lineWidth: 1.6
                )
            }

            // C. Hollow White Biomechanical Pivot Nodes
            for joint in SkeletonJoint.allCases {
                guard let p = pt(joint) else { continue }
                let isDragged = activeDraggedJoint == joint
                let isProb = problemJoints.contains(joint)
                let radius: CGFloat = isDragged ? 6.5 : 3.8

                let nodeRect = CGRect(
                    x: p.x - radius,
                    y: p.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                context.fill(
                    Path(ellipseIn: nodeRect),
                    with: .color(Color(red: 0.08, green: 0.11, blue: 0.15))
                )
                context.stroke(
                    Path(ellipseIn: nodeRect),
                    with: .color(isProb ? Color(red: 1.0, green: 0.32, blue: 0.44) : Color.white),
                    lineWidth: 1.9
                )
            }
        }
    }

    // MARK: - 5. Diagnostic Callout Boxes in Outer Margins (Non-Overlapping)

    private func diagnosticCalloutsLayer(size: CGSize) -> some View {
        let callouts = buildCallouts(size: size)
        return ZStack {
            Canvas { context, _ in
                for item in callouts {
                    var line = Path()
                    line.move(to: item.anchorPoint)
                    line.addLine(to: item.elbowPoint)
                    line.addLine(to: item.boxAttachPoint)
                    context.stroke(
                        line,
                        with: .color(item.accentColor.opacity(0.80)),
                        style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round)
                    )
                }
            }

            ForEach(callouts) { item in
                HStack(spacing: 5) {
                    Circle()
                        .fill(item.accentColor)
                        .frame(width: 6, height: 6)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title)
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(item.subtitle)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(item.accentColor)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color(red: 0.06, green: 0.08, blue: 0.12).opacity(0.90))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(item.accentColor.opacity(0.65), lineWidth: 1.1)
                        )
                )
                .position(item.boxCenter)
            }
        }
    }

    // MARK: - Helpers

    private func computeClubHeadPoint(
        handsPt: CGPoint,
        skeleton: PoseSkeleton,
        canvasSize: CGSize,
        isIdeal: Bool
    ) -> CGPoint {
        let w = canvasSize.width * figureScale
        let h = canvasSize.height * figureScale
        let groundBallPt = project(CGPoint(x: 0.50, y: 0.855), in: canvasSize)

        switch stageID {
        case .setup, .grip, .impact:
            return groundBallPt
        case .backswing:
            if isIdeal || evaluation.isAllPassing {
                return CGPoint(x: handsPt.x + w * 0.16, y: handsPt.y - h * 0.11)
            } else {
                return CGPoint(x: handsPt.x + w * 0.22, y: handsPt.y + h * 0.02)
            }
        case .finish:
            return CGPoint(x: handsPt.x + w * 0.17, y: handsPt.y + h * 0.11)
        }
    }

    private struct CalloutItem: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let accentColor: Color
        let anchorPoint: CGPoint
        let elbowPoint: CGPoint
        let boxAttachPoint: CGPoint
        let boxCenter: CGPoint
    }

    private func buildCallouts(size: CGSize) -> [CalloutItem] {
        let w = size.width
        let h = size.height
        var items: [CalloutItem] = []

        let activeChecks = evaluation.checkpoints.prefix(2)
        for (idx, cp) in activeChecks.enumerated() {
            let joint = cp.highlightedJoints.first ?? .leftElbow
            guard let normPt = currentSkeleton.joints[joint] else { continue }
            let anchor = project(normPt, in: size)
            let isLeft = idx == 0

            // Place callout boxes strictly in the outer left/right corners so they never cover the figure
            let boxX = isLeft ? min(54, w * 0.15) : max(w - 54, w * 0.85)
            let boxY = isLeft ? max(36, h * 0.18) : max(36, h * 0.22)
            let attachX = isLeft ? boxX + 38 : boxX - 38
            let elbowX = isLeft ? (anchor.x + attachX) / 2.0 : (anchor.x + attachX) / 2.0

            let color: Color = cp.status == .perfect
                ? Color(red: 0.16, green: 0.85, blue: 0.52)
                : (cp.status == .almost ? .orange : Color(red: 1.0, green: 0.23, blue: 0.36))

            items.append(
                CalloutItem(
                    id: cp.id,
                    title: cp.title,
                    subtitle: cp.currentValueText,
                    accentColor: color,
                    anchorPoint: anchor,
                    elbowPoint: CGPoint(x: elbowX, y: boxY),
                    boxAttachPoint: CGPoint(x: attachX, y: boxY),
                    boxCenter: CGPoint(x: boxX, y: boxY)
                )
            )
        }
        return items
    }

    private func nearestJoint(to normalizedPoint: CGPoint, in skeleton: PoseSkeleton) -> SkeletonJoint? {
        var bestJoint: SkeletonJoint?
        var bestDist: CGFloat = 0.14
        for (joint, pt) in skeleton.joints {
            let d = hypot(pt.x - normalizedPoint.x, pt.y - normalizedPoint.y)
            if d < bestDist {
                bestDist = d
                bestJoint = joint
            }
        }
        return bestJoint
    }
}
