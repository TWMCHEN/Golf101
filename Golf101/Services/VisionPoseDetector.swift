//
//  VisionPoseDetector.swift
//  Golf101
//
//  Created by Golf101 AI Coach on 2026/10/23.
//

import Foundation
import AVFoundation
import Vision
import CoreGraphics
import Observation

enum CameraAuthorizationState: Equatable {
    case unknown
    case authorized
    case denied
    case unavailable
}

@Observable
final class VisionPoseDetector {
    var authorizationState: CameraAuthorizationState = .unknown
    var isUsingFrontCamera: Bool = true
    var isCameraRunning: Bool = false
    var isHumanDetected: Bool = false
    var detectedSkeleton: PoseSkeleton?

    let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.MichaelChen.Golf101.CameraSessionQueue")
    private let videoOutputQueue = DispatchQueue(label: "com.MichaelChen.Golf101.VideoOutputQueue", qos: .userInteractive)
    private var frameProcessor: VisionFrameProcessor?

    init() {
        let processor = VisionFrameProcessor { [weak self] newSkeleton, humanFound in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isHumanDetected = humanFound
                if let newSkeleton {
                    if let existing = self.detectedSkeleton {
                        self.detectedSkeleton = Self.smooth(previous: existing, current: newSkeleton, alpha: 0.42)
                    } else {
                        self.detectedSkeleton = newSkeleton
                    }
                }
            }
        }
        self.frameProcessor = processor
    }

    func requestPermissionAndStart() {
        #if targetEnvironment(simulator)
        authorizationState = .unavailable
        isCameraRunning = false
        #else
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            authorizationState = .authorized
            configureAndStartSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if granted {
                        self.authorizationState = .authorized
                        self.configureAndStartSession()
                    } else {
                        self.authorizationState = .denied
                    }
                }
            }
        case .denied, .restricted:
            authorizationState = .denied
        @unknown default:
            authorizationState = .denied
        }
        #endif
    }

    func toggleCameraPosition() {
        isUsingFrontCamera.toggle()
        frameProcessor?.isMirrored = isUsingFrontCamera
        guard authorizationState == .authorized else { return }
        configureAndStartSession()
    }

    func stopSession() {
        let session = captureSession
        sessionQueue.async {
            if session.isRunning {
                session.stopRunning()
            }
            Task { @MainActor [weak self] in
                self?.isCameraRunning = false
            }
        }
    }

    private func configureAndStartSession() {
        let session = captureSession
        let useFront = isUsingFrontCamera
        let outputDelegate = frameProcessor
        let outputQueue = videoOutputQueue
        frameProcessor?.isMirrored = useFront

        sessionQueue.async {
            session.beginConfiguration()
            session.sessionPreset = .high

            for input in session.inputs {
                session.removeInput(input)
            }
            for output in session.outputs {
                session.removeOutput(output)
            }

            let position: AVCaptureDevice.Position = useFront ? .front : .back
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
                    ?? AVCaptureDevice.default(for: .video),
                  let deviceInput = try? AVCaptureDeviceInput(device: camera),
                  session.canAddInput(deviceInput) else {
                session.commitConfiguration()
                Task { @MainActor [weak self] in
                    self?.authorizationState = .unavailable
                    self?.isCameraRunning = false
                }
                return
            }

            session.addInput(deviceInput)

            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
            ]
            videoOutput.setSampleBufferDelegate(outputDelegate, queue: outputQueue)

            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }

            session.commitConfiguration()
            if !session.isRunning {
                session.startRunning()
            }

            Task { @MainActor [weak self] in
                self?.isCameraRunning = true
            }
        }
    }

    private static func smooth(previous: PoseSkeleton, current: PoseSkeleton, alpha: CGFloat) -> PoseSkeleton {
        var mergedJoints = previous.joints
        for (joint, newPt) in current.joints {
            if let oldPt = previous.joints[joint] {
                mergedJoints[joint] = CGPoint(
                    x: oldPt.x * (1.0 - alpha) + newPt.x * alpha,
                    y: oldPt.y * (1.0 - alpha) + newPt.y * alpha
                )
            } else {
                mergedJoints[joint] = newPt
            }
        }
        let smoothedV = previous.detectedGripVAngle * Double(1.0 - alpha) + current.detectedGripVAngle * Double(alpha)
        let smoothedConn = previous.handConnectionScore * Double(1.0 - alpha) + current.handConnectionScore * Double(alpha)
        return PoseSkeleton(
            joints: mergedJoints,
            confidences: current.confidences,
            detectedGripVAngle: smoothedV,
            handConnectionScore: smoothedConn
        )
    }
}

// MARK: - Nonisolated Vision Frame Processor

nonisolated final class VisionFrameProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    var isMirrored: Bool = true
    private let onResult: @Sendable (PoseSkeleton?, Bool) -> Void
    private var frameCounter: Int = 0

    init(onResult: @escaping @Sendable (PoseSkeleton?, Bool) -> Void) {
        self.onResult = onResult
        super.init()
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        frameCounter += 1
        // Process every 2nd frame (~15fps) for smooth performance and low thermal impact
        guard frameCounter % 2 == 0,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let bodyRequest = VNDetectHumanBodyPoseRequest()
        let handRequest = VNDetectHumanHandPoseRequest()
        handRequest.maximumHandCount = 2

        let orientation: CGImagePropertyOrientation = isMirrored ? .leftMirrored : .right
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])

        do {
            try handler.perform([bodyRequest, handRequest])
        } catch {
            return
        }

        guard let bodyObservation = bodyRequest.results?.first else {
            onResult(nil, false)
            return
        }

        var joints: [SkeletonJoint: CGPoint] = [:]
        var confidences: [SkeletonJoint: Float] = [:]

        let mapping: [(VNHumanBodyPoseObservation.JointName, SkeletonJoint)] = [
            (.nose, .nose),
            (.neck, .neck),
            (.leftShoulder, .leftShoulder),
            (.rightShoulder, .rightShoulder),
            (.leftElbow, .leftElbow),
            (.rightElbow, .rightElbow),
            (.leftWrist, .leftWrist),
            (.rightWrist, .rightWrist),
            (.root, .root),
            (.leftHip, .leftHip),
            (.rightHip, .rightHip),
            (.leftKnee, .leftKnee),
            (.rightKnee, .rightKnee),
            (.leftAnkle, .leftAnkle),
            (.rightAnkle, .rightAnkle)
        ]

        for (vnJoint, targetJoint) in mapping {
            if let recognized = try? bodyObservation.recognizedPoint(vnJoint),
               recognized.confidence > 0.15 {
                // Vision normalized coordinates have origin at bottom-left; convert to top-left (0...1)
                joints[targetJoint] = CGPoint(x: recognized.location.x, y: 1.0 - recognized.location.y)
                confidences[targetJoint] = recognized.confidence
            }
        }

        // Compute V-Groove angle and hand closeness from VNDetectHumanHandPoseRequest if hands are visible
        var vAngle: Double = 20.0
        var handConnection: Double = 0.88

        if let handObservations = handRequest.results, !handObservations.isEmpty {
            var vAngles: [Double] = []
            var wristCenters: [CGPoint] = []

            for hand in handObservations {
                if let thumbTip = try? hand.recognizedPoint(.thumbTip),
                   let indexMCP = try? hand.recognizedPoint(.indexMCP),
                   let wristPt = try? hand.recognizedPoint(.wrist),
                   thumbTip.confidence > 0.2, indexMCP.confidence > 0.2, wristPt.confidence > 0.2 {
                    let midCrotch = CGPoint(
                        x: (thumbTip.location.x + indexMCP.location.x) / 2.0,
                        y: 1.0 - (thumbTip.location.y + indexMCP.location.y) / 2.0
                    )
                    let wristTopLeft = CGPoint(x: wristPt.location.x, y: 1.0 - wristPt.location.y)
                    wristCenters.append(wristTopLeft)

                    let dx = Double(wristTopLeft.x - midCrotch.x)
                    let dy = Double(midCrotch.y - wristTopLeft.y)
                    let deg = atan2(dx, max(0.01, abs(dy))) * 180.0 / .pi
                    vAngles.append(deg)
                }
            }

            if !vAngles.isEmpty {
                vAngle = vAngles.reduce(0, +) / Double(vAngles.count)
            }
            if wristCenters.count >= 2 {
                let d = hypot(wristCenters[0].x - wristCenters[1].x, wristCenters[0].y - wristCenters[1].y)
                handConnection = max(0.2, min(1.0, 1.0 - Double(d) * 3.8))
            }
        } else if let lw = joints[.leftWrist], let rw = joints[.rightWrist], let rs = joints[.rightShoulder] {
            // Fallback estimation from wrist-to-right-shoulder vector
            let midWrist = CGPoint(x: (lw.x + rw.x) / 2.0, y: (lw.y + rw.y) / 2.0)
            let dx = Double(rs.x - midWrist.x)
            let dy = max(0.05, Double(midWrist.y - rs.y))
            vAngle = atan2(dx, dy) * 180.0 / .pi
        }

        let skeleton = PoseSkeleton(
            joints: joints,
            confidences: confidences,
            detectedGripVAngle: vAngle,
            handConnectionScore: handConnection
        )
        onResult(skeleton, joints.count >= 5)
    }
}
