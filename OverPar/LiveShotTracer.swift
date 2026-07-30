import AVFoundation
import SwiftUI
import UIKit
import Vision

struct LiveShotTracerCapture {
    var temporaryVideoURL: URL
    var tracePoints: [GalleryItem.TracePoint]
    var observedPointCount: Int
}

final class LiveShotTracerController: NSObject, ObservableObject {
    enum State: Equatable {
        case requestingPermission
        case configuring
        case ready
        case recording
        case finishing
        case saved
        case unavailable(String)
    }

    let session = AVCaptureSession()

    @Published private(set) var state: State = .requestingPermission
    @Published private(set) var isGolferAligned = false
    @Published private(set) var isCameraSteady = true
    @Published private(set) var tracePoints: [GalleryItem.TracePoint] = []
    @Published private(set) var observedPointCount = 0
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var trackingMessage = "Align the golfer and ball"

    var onCapture: ((LiveShotTracerCapture) -> Void)?

    private let sessionQueue = DispatchQueue(label: "com.overpar.tracer.session")
    private let analysisQueue = DispatchQueue(label: "com.overpar.tracer.analysis", qos: .userInitiated)
    private let movieOutput = AVCaptureMovieFileOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let detector = WhiteBallMotionDetector()
    private var isConfigured = false
    private var timer: Timer?
    private var recordingStartedAt: Date?
    private var poseFrameCounter = 0

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            requestAudioThenConfigure()
        case .notDetermined:
            state = .requestingPermission
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    granted ? self.requestAudioThenConfigure() : self.fail("Camera access is required to record a live trace.")
                }
            }
        case .denied, .restricted:
            fail("Camera access is off. Enable it in Settings to record a live trace.")
        @unknown default:
            fail("The camera is unavailable on this device.")
        }
    }

    private func requestAudioThenConfigure() {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined else {
            configureAndStart()
            return
        }
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
            DispatchQueue.main.async {
                // A denied microphone still permits a silent visual trace.
                self?.configureAndStart()
            }
        }
    }

    func stopSession() {
        timer?.invalidate()
        timer = nil
        if movieOutput.isRecording {
            movieOutput.stopRecording()
        }
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func toggleRecording() {
        switch state {
        case .ready:
            beginRecording()
        case .recording:
            finishRecording()
        default:
            break
        }
    }

    private func configureAndStart() {
        state = .configuring
        sessionQueue.async { [weak self] in
            guard let self else { return }
            do {
                if !self.isConfigured {
                    try self.configureSession()
                    self.isConfigured = true
                }
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                Task { @MainActor in
                    self.state = .ready
                    self.trackingMessage = "Align the golfer and ball"
                }
            } catch {
                Task { @MainActor in
                    self.fail("OverPar could not start the camera: \(error.localizedDescription)")
                }
            }
        }
    }

    private func configureSession() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .high

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw TracerCameraError.noBackCamera
        }
        let videoInput = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(videoInput) else { throw TracerCameraError.cannotAddVideoInput }
        session.addInput(videoInput)

        if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
           let microphone = AVCaptureDevice.default(for: .audio) {
            let audioInput = try? AVCaptureDeviceInput(device: microphone)
            if let audioInput, session.canAddInput(audioInput) {
                session.addInput(audioInput)
            }
        }

        selectSixtyFPSFormat(on: camera)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String:
                kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        videoOutput.setSampleBufferDelegate(self, queue: analysisQueue)
        guard session.canAddOutput(videoOutput) else { throw TracerCameraError.cannotAddAnalysisOutput }
        session.addOutput(videoOutput)

        guard session.canAddOutput(movieOutput) else { throw TracerCameraError.cannotAddMovieOutput }
        session.addOutput(movieOutput)
        movieOutput.maxRecordedDuration = CMTime(seconds: 20, preferredTimescale: 600)
        movieOutput.minFreeDiskSpaceLimit = 80 * 1_024 * 1_024

        configurePortraitOrientation(videoOutput.connection(with: .video))
        configurePortraitOrientation(movieOutput.connection(with: .video))
    }

    private func selectSixtyFPSFormat(on device: AVCaptureDevice) {
        let candidates = device.formats.filter { format in
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return dimensions.width >= 1280
                && format.videoSupportedFrameRateRanges.contains(where: { $0.maxFrameRate >= 60 })
        }
        guard let format = candidates.min(by: {
            let lhs = CMVideoFormatDescriptionGetDimensions($0.formatDescription)
            let rhs = CMVideoFormatDescriptionGetDimensions($1.formatDescription)
            return lhs.width * lhs.height < rhs.width * rhs.height
        }) else { return }

        do {
            try device.lockForConfiguration()
            device.activeFormat = format
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 60)
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 60)
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
        } catch {
            // High frame rate improves tiny-ball visibility, but normal capture remains usable.
        }
    }

    private func configurePortraitOrientation(_ connection: AVCaptureConnection?) {
        guard let connection else { return }
        if connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        } else if connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
    }

    private func beginRecording() {
        guard !movieOutput.isRecording else { return }
        detector.reset()
        tracePoints = []
        observedPointCount = 0
        elapsed = 0
        trackingMessage = "Waiting for the swing…"
        recordingStartedAt = Date()
        state = .recording

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("overpar-live-\(UUID().uuidString).mov")
        try? FileManager.default.removeItem(at: url)
        movieOutput.startRecording(to: url, recordingDelegate: self)

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let started = self.recordingStartedAt else { return }
                self.elapsed = Date().timeIntervalSince(started)
            }
        }
    }

    private func finishRecording() {
        guard movieOutput.isRecording else { return }
        state = .finishing
        trackingMessage = observedPointCount >= 3 ? "Finishing your live trace…" : "Saving the original video…"
        timer?.invalidate()
        timer = nil
        movieOutput.stopRecording()
    }

    private func fail(_ message: String) {
        state = .unavailable(message)
        trackingMessage = message
    }

    private func updatePose(from pixelBuffer: CVPixelBuffer) {
        let request = VNDetectHumanBodyPoseRequest()
        request.regionOfInterest = CGRect(x: 0.08, y: 0.08, width: 0.84, height: 0.86)
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        do {
            try handler.perform([request])
            guard let observation = request.results?.first,
                  let points = try? observation.recognizedPoints(.all)
            else {
                Task { @MainActor in self.isGolferAligned = false }
                return
            }
            let confident = points.values.filter { $0.confidence > 0.35 }
            guard confident.count >= 7 else {
                Task { @MainActor in self.isGolferAligned = false }
                return
            }
            let xs = confident.map(\.location.x)
            let ys = confident.map { 1 - $0.location.y }
            let width = (xs.max() ?? 0) - (xs.min() ?? 0)
            let height = (ys.max() ?? 0) - (ys.min() ?? 0)
            let centerX = ((xs.max() ?? 0) + (xs.min() ?? 0)) / 2
            let centerY = ((ys.max() ?? 0) + (ys.min() ?? 0)) / 2
            let aligned = height > 0.28 && width > 0.08
                && (0.2...0.8).contains(centerX)
                && (0.38...0.78).contains(centerY)
            Task { @MainActor in self.isGolferAligned = aligned }
        } catch {
            Task { @MainActor in self.isGolferAligned = false }
        }
    }
}

extension LiveShotTracerController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        poseFrameCounter += 1
        if state == .ready, poseFrameCounter.isMultiple(of: 12) {
            updatePose(from: pixelBuffer)
        }
        guard state == .recording else { return }
        let result = detector.process(pixelBuffer)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isCameraSteady = result.isCameraSteady
            if !result.isCameraSteady {
                self.trackingMessage = "Keep the phone still"
            } else if result.observedCount >= 3 {
                self.trackingMessage = "Tracking live"
            } else if result.hasDetectedImpact {
                self.trackingMessage = "Ball found…"
            } else {
                self.trackingMessage = "Waiting for the swing…"
            }
            self.tracePoints = result.points
            self.observedPointCount = result.observedCount
        }
    }
}

extension LiveShotTracerController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.timer?.invalidate()
            self.timer = nil
            if let error {
                self.fail("The recording could not be saved: \(error.localizedDescription)")
                return
            }
            let capture = LiveShotTracerCapture(
                temporaryVideoURL: outputFileURL,
                tracePoints: self.tracePoints,
                observedPointCount: self.observedPointCount
            )
            self.state = .saved
            self.trackingMessage = self.observedPointCount >= 3
                ? "Live trace saved to Gallery"
                : "Original saved · no reliable ball trace found"
            self.onCapture?(capture)
        }
    }
}

private enum TracerCameraError: LocalizedError {
    case noBackCamera
    case cannotAddVideoInput
    case cannotAddAnalysisOutput
    case cannotAddMovieOutput

    var errorDescription: String? {
        switch self {
        case .noBackCamera: "No rear camera is available."
        case .cannotAddVideoInput: "The rear camera could not be connected."
        case .cannotAddAnalysisOutput: "Live frame analysis is unavailable."
        case .cannotAddMovieOutput: "Video recording is unavailable."
        }
    }
}

private final class WhiteBallMotionDetector {
    struct Result {
        var points: [GalleryItem.TracePoint]
        var observedCount: Int
        var hasDetectedImpact: Bool
        var isCameraSteady: Bool
    }

    private let sampleStep = 6
    private let ballOrigin = CGPoint(x: 0.5, y: 0.77)
    private var previousLuma: [UInt8] = []
    private var sampledWidth = 0
    private var sampledHeight = 0
    private var frameNumber = 0
    private var hasDetectedImpact = false
    private var observed: [CGPoint] = []
    private var missedFrames = 0

    func reset() {
        previousLuma = []
        sampledWidth = 0
        sampledHeight = 0
        frameNumber = 0
        hasDetectedImpact = false
        observed = []
        missedFrames = 0
    }

    func process(_ pixelBuffer: CVPixelBuffer) -> Result {
        frameNumber += 1
        guard frameNumber.isMultiple(of: 2),
              CVPixelBufferGetPlaneCount(pixelBuffer) > 0
        else {
            return makeResult(cameraSteady: true)
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else {
            return makeResult(cameraSteady: true)
        }

        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let rowBytes = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        let currentSampledWidth = max(1, width / sampleStep)
        let currentSampledHeight = max(1, height / sampleStep)
        let bytes = base.assumingMemoryBound(to: UInt8.self)
        var current = [UInt8](repeating: 0, count: currentSampledWidth * currentSampledHeight)

        for sy in 0..<currentSampledHeight {
            let y = sy * sampleStep
            let sourceRow = bytes.advanced(by: y * rowBytes)
            let destination = sy * currentSampledWidth
            for sx in 0..<currentSampledWidth {
                current[destination + sx] = sourceRow[sx * sampleStep]
            }
        }

        guard previousLuma.count == current.count else {
            previousLuma = current
            sampledWidth = currentSampledWidth
            sampledHeight = currentSampledHeight
            return makeResult(cameraSteady: true)
        }

        sampledWidth = currentSampledWidth
        sampledHeight = currentSampledHeight
        var globalChanged = 0
        var swingChanged = 0
        var candidates: [(point: CGPoint, score: Double)] = []
        let last = observed.last ?? ballOrigin
        let previous = observed.dropLast().last
        let predicted: CGPoint
        if let previous {
            predicted = CGPoint(
                x: last.x + (last.x - previous.x),
                y: last.y + (last.y - previous.y)
            )
        } else {
            predicted = last
        }

        for sy in 1..<(currentSampledHeight - 1) {
            let ny = Double(sy) / Double(currentSampledHeight)
            for sx in 1..<(currentSampledWidth - 1) {
                let index = sy * currentSampledWidth + sx
                let luma = Int(current[index])
                let difference = abs(luma - Int(previousLuma[index]))
                if difference > 20 { globalChanged += 1 }

                let nx = Double(sx) / Double(currentSampledWidth)
                if (0.16...0.84).contains(nx), (0.38...0.9).contains(ny), difference > 24 {
                    swingChanged += 1
                }
                guard luma > 168, difference > 18, ny < 0.8 else { continue }

                let point = CGPoint(x: nx, y: ny)
                let reference = hasDetectedImpact ? predicted : ballOrigin
                let distance = hypot(point.x - reference.x, point.y - reference.y)
                let maximumJump = hasDetectedImpact ? 0.17 : 0.095
                guard distance < maximumJump else { continue }

                let neighbourDifferences = [
                    index - 1, index + 1, index - currentSampledWidth, index + currentSampledWidth
                ].filter { abs(Int(current[$0]) - Int(previousLuma[$0])) > 12 }.count
                guard neighbourDifferences >= 1 else { continue }

                let upwardBonus = point.y <= last.y + 0.025 ? 18.0 : -24.0
                let score = Double(difference) + Double(luma) * 0.08
                    - distance * 340 + upwardBonus
                candidates.append((point, score))
            }
        }

        let totalSamples = max(1, current.count)
        let cameraSteady = Double(globalChanged) / Double(totalSamples) < 0.22
        if !cameraSteady {
            missedFrames += 1
            previousLuma = current
            return makeResult(cameraSteady: false)
        }

        if !hasDetectedImpact, swingChanged > max(35, totalSamples / 420) {
            hasDetectedImpact = true
        }

        if hasDetectedImpact, let best = candidates.max(by: { $0.score < $1.score }), best.score > 5 {
            let smoothed: CGPoint
            if let last = observed.last {
                smoothed = CGPoint(
                    x: last.x * 0.28 + best.point.x * 0.72,
                    y: last.y * 0.28 + best.point.y * 0.72
                )
            } else {
                smoothed = best.point
            }
            if observed.isEmpty || hypot(smoothed.x - last.x, smoothed.y - last.y) > 0.006 {
                observed.append(smoothed)
                if observed.count > 48 { observed.removeFirst() }
            }
            missedFrames = 0
        } else if hasDetectedImpact {
            missedFrames += 1
        }

        previousLuma = current
        return makeResult(cameraSteady: true)
    }

    private func makeResult(cameraSteady: Bool) -> Result {
        let visual = completedVisualPath(from: observed)
        return Result(
            points: visual,
            observedCount: observed.count,
            hasDetectedImpact: hasDetectedImpact,
            isCameraSteady: cameraSteady
        )
    }

    private func completedVisualPath(from points: [CGPoint]) -> [GalleryItem.TracePoint] {
        guard !points.isEmpty else { return [] }
        var output = [GalleryItem.TracePoint(
            x: ballOrigin.x,
            y: ballOrigin.y,
            source: .observed
        )]
        output.append(contentsOf: points.map {
            GalleryItem.TracePoint(x: $0.x, y: $0.y, source: .observed)
        })

        guard points.count >= 3, missedFrames >= 3, let last = points.last else { return output }
        let previous = points[points.count - 2]
        var velocity = CGPoint(x: last.x - previous.x, y: last.y - previous.y)
        for index in 1...8 {
            velocity.x *= 0.84
            velocity.y = velocity.y * 0.76 + 0.0035
            let prior = output.last!
            let x = min(0.97, max(0.03, prior.x + velocity.x))
            let y = min(0.92, max(0.04, prior.y + velocity.y))
            output.append(GalleryItem.TracePoint(x: x, y: y, source: .extrapolated))
            if index > 4, y > last.y { break }
        }
        return output
    }
}

struct LiveShotTracerCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var store: AppStore
    @StateObject private var controller = LiveShotTracerController()
    @State private var hasSavedCapture = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TracerCameraPreview(session: controller.session, points: controller.tracePoints)
                .ignoresSafeArea()

            if controller.state == .ready {
                GolferAlignmentTemplate(isRightHanded: store.profile.isRightHanded)
                    .transition(.opacity)
            }

            LinearGradient(
                colors: [.black.opacity(0.62), .clear, .black.opacity(0.76)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                Spacer()
                guidance
                controls
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            controller.onCapture = saveCapture
            controller.start()
        }
        .onDisappear { controller.stopSession() }
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.bold())
                    .frame(width: 46, height: 46)
                    .background(.black.opacity(0.45), in: Circle())
            }
            Spacer()
            VStack(spacing: 2) {
                Text(controller.state == .recording ? formattedTime : "LIVE SHOT TRACER")
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .monospacedDigit()
                Text(controller.state == .recording ? controller.trackingMessage : "Fixed camera · white ball")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
            Image(systemName: controller.isCameraSteady ? "hand.raised.slash.fill" : "iphone.gen3.radiowaves.left.and.right")
                .font(.title3)
                .foregroundStyle(controller.isCameraSteady ? .white : .yellow)
                .frame(width: 46, height: 46)
                .background(.black.opacity(0.45), in: Circle())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.top, 10)
    }

    private var guidance: some View {
        VStack(spacing: 8) {
            if case let .unavailable(message) = controller.state {
                Label(message, systemImage: "camera.fill")
                    .foregroundStyle(.white)
            } else if hasSavedCapture {
                Label(controller.trackingMessage, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.white)
            } else {
                Label(alignmentText, systemImage: alignmentSymbol)
                    .foregroundStyle(controller.state == .ready && controller.isGolferAligned ? Color.green : .white)
                Text("Keep the phone fixed and leave clear sky in the flight direction.")
                    .foregroundStyle(.white.opacity(0.78))
            }
        }
        .font(.system(.subheadline, design: .rounded, weight: .semibold))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .padding(.vertical, 13)
        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 20)
    }

    private var controls: some View {
        HStack {
            VStack(spacing: 5) {
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 28, height: 28)
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                Text("Trace").font(.caption2.bold())
            }
            .frame(maxWidth: .infinity)

            Button {
                if hasSavedCapture {
                    dismiss()
                } else {
                    controller.toggleRecording()
                }
            } label: {
                ZStack {
                    Circle()
                        .stroke(.white, lineWidth: 5)
                        .frame(width: 86, height: 86)
                    if controller.state == .recording {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red)
                            .frame(width: 42, height: 42)
                    } else if hasSavedCapture {
                        Image(systemName: "checkmark")
                            .font(.title.bold())
                            .foregroundStyle(OverParTheme.forestDark)
                            .frame(width: 70, height: 70)
                            .background(.white, in: Circle())
                    } else {
                        Circle().fill(Color.red).frame(width: 70, height: 70)
                    }
                }
            }
            .disabled(!canUseShutter)
            .accessibilityLabel(shutterLabel)
            .frame(maxWidth: .infinity)

            VStack(spacing: 5) {
                Image(systemName: "figure.golf")
                    .font(.title2)
                    .frame(width: 32, height: 32)
                Text(store.profile.isRightHanded ? "Right" : "Left")
                    .font(.caption2.bold())
            }
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(.white)
        .padding(.top, 18)
        .padding(.bottom, 26)
        .background(.black.opacity(0.78))
    }

    private var canUseShutter: Bool {
        switch controller.state {
        case .ready, .recording, .saved: true
        default: false
        }
    }

    private var shutterLabel: String {
        if hasSavedCapture { return "Done" }
        return controller.state == .recording ? "Stop recording" : "Start live shot recording"
    }

    private var alignmentText: String {
        switch controller.state {
        case .requestingPermission: "Allowing camera…"
        case .configuring: "Preparing 60 fps camera…"
        case .ready:
            controller.isGolferAligned ? "Golfer aligned · press record" : "Place the golfer over either outline"
        case .recording, .finishing, .saved: controller.trackingMessage
        case .unavailable: "Camera unavailable"
        }
    }

    private var alignmentSymbol: String {
        controller.isGolferAligned ? "checkmark.circle.fill" : "viewfinder"
    }

    private var formattedTime: String {
        let seconds = Int(controller.elapsed)
        let hundredths = Int((controller.elapsed - Double(seconds)) * 100)
        return String(format: "00:%02d:%02d", seconds, hundredths)
    }

    private func saveCapture(_ capture: LiveShotTracerCapture) {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Gallery", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let filename = "\(UUID().uuidString).mov"
            let destination = directory.appendingPathComponent(filename)
            try FileManager.default.moveItem(at: capture.temporaryVideoURL, to: destination)
            let round = store.activeRound
            let course = round.flatMap { active in store.courses.first { $0.id == active.courseID } }
            store.addGalleryVideo(
                filename: filename,
                courseName: course?.name,
                hole: round?.holeNumber,
                tracePoints: capture.tracePoints,
                observedPointCount: capture.observedPointCount
            )
            withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82)) {
                hasSavedCapture = true
            }
        } catch {
            try? FileManager.default.removeItem(at: capture.temporaryVideoURL)
        }
    }
}

private struct GolferAlignmentTemplate: View {
    let isRightHanded: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                templateGolfer
                    .frame(width: proxy.size.width * 0.28)
                    .position(x: proxy.size.width * 0.34, y: proxy.size.height * 0.64)
                templateGolfer
                    .scaleEffect(x: -1, y: 1)
                    .frame(width: proxy.size.width * 0.28)
                    .position(x: proxy.size.width * 0.66, y: proxy.size.height * 0.64)
                VStack(spacing: 5) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 28, weight: .bold))
                    Circle().fill(.white.opacity(0.18)).frame(width: 38, height: 12)
                }
                .foregroundStyle(.white.opacity(0.8))
                .position(x: proxy.size.width * 0.5, y: proxy.size.height * 0.77)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var templateGolfer: some View {
        Image(systemName: "figure.golf")
            .resizable()
            .scaledToFit()
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.white.opacity(0.52))
    }
}

private final class TracerPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    let traceLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        previewLayer.videoGravity = .resizeAspectFill
        traceLayer.fillColor = UIColor.clear.cgColor
        traceLayer.strokeColor = UIColor.systemYellow.cgColor
        traceLayer.lineWidth = 5
        traceLayer.lineCap = .round
        traceLayer.lineJoin = .round
        layer.addSublayer(traceLayer)
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        traceLayer.frame = bounds
    }

    func update(points: [GalleryItem.TracePoint]) {
        guard !points.isEmpty else {
            traceLayer.path = nil
            return
        }
        let path = UIBezierPath()
        for (index, point) in points.enumerated() {
            let converted = previewLayer.layerPointConverted(
                fromCaptureDevicePoint: CGPoint(x: point.x, y: point.y)
            )
            if index == 0 { path.move(to: converted) } else { path.addLine(to: converted) }
        }
        traceLayer.path = path.cgPath
    }
}

private struct TracerCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let points: [GalleryItem.TracePoint]

    func makeUIView(context: Context) -> TracerPreviewUIView {
        let view = TracerPreviewUIView()
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ view: TracerPreviewUIView, context: Context) {
        view.update(points: points)
    }
}
