import CoreGraphics
import Foundation

struct PostPasteLearningObservation: Equatable, Sendable {
    let recognizedText: String
    let confidence: Double
}

final class PostPasteLearningCoordinator {
    typealias Scheduler = @Sendable (TimeInterval, @escaping @Sendable () -> Void) -> Void
    typealias Revisit = @Sendable (PasteSession) async -> PostPasteLearningObservation?

    static let learningDelay: TimeInterval = 15
    private static let minimumConfidence = 0.95
    private static let maximumReplacementWordCount = 4

    var learningEnabled: Bool

    private let correctionStore: CorrectionStore
    private let scheduler: Scheduler
    private let revisit: Revisit

    var debugLogger: ((DebugLogCategory, String) -> Void)?

    init(
        correctionStore: CorrectionStore,
        learningEnabled: Bool = true,
        scheduler: @escaping Scheduler = { delay, work in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        },
        revisit: @escaping Revisit
    ) {
        self.correctionStore = correctionStore
        self.learningEnabled = learningEnabled
        self.scheduler = scheduler
        self.revisit = revisit
    }

    func handlePaste(_ session: PasteSession) {
        guard learningEnabled else {
            debugLogger?(.cleanup, "Post-paste learning skipped because it is disabled.")
            return
        }

        debugLogger?(.cleanup, "Scheduled post-paste learning revisit.")
        scheduler(Self.learningDelay) {
            Task {
                await self.learn(from: session)
            }
        }
    }

    private func learn(from session: PasteSession) async {
        guard learningEnabled else {
            debugLogger?(.cleanup, "Post-paste learning skipped because it is disabled.")
            return
        }

        debugLogger?(.cleanup, "Post-paste learning revisit started.")

        guard let observation = await revisit(session) else {
            debugLogger?(.cleanup, "Post-paste learning skipped because no OCR revisit observation was captured.")
            return
        }

        guard observation.confidence >= Self.minimumConfidence else {
            debugLogger?(.cleanup, "Post-paste learning skipped because OCR confidence \(observation.confidence) was below threshold.")
            return
        }

        guard let replacement = Self.inferredReplacement(
            from: session.pastedText,
            to: observation.recognizedText
        ) else {
            debugLogger?(.cleanup, "Post-paste learning skipped because no narrow correction could be inferred.")
            return
        }

        guard learningEnabled else {
            debugLogger?(.cleanup, "Post-paste learning skipped because it was disabled before storing.")
            return
        }

        await MainActor.run {
            guard self.learningEnabled else {
                self.debugLogger?(.cleanup, "Post-paste learning skipped because it was disabled before storing.")
                return
            }

            self.store(replacement)
        }
    }

    private func store(_ replacement: MisheardReplacement) {
        correctionStore.appendCommonlyMisheard(replacement)
        debugLogger?(.cleanup, "Post-paste learning learned replacement: \(replacement.wrong) -> \(replacement.right)")
    }

    private static func inferredReplacement(from original: String, to observed: String) -> MisheardReplacement? {
        let trimmedOriginal = original.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedObserved = observed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOriginal.isEmpty,
              !trimmedObserved.isEmpty,
              trimmedOriginal.caseInsensitiveCompare(trimmedObserved) != .orderedSame else {
            return nil
        }

        let originalWords = words(in: trimmedOriginal)
        let observedWords = words(in: trimmedObserved)
        let sharedPrefixCount = sharedPrefixLength(between: originalWords, and: observedWords)
        let sharedSuffixCount = sharedSuffixLength(
            between: originalWords,
            and: observedWords,
            excludingPrefix: sharedPrefixCount
        )

        guard sharedPrefixCount > 0 || sharedSuffixCount > 0 else {
            return nil
        }

        let originalEndIndex = originalWords.count - sharedSuffixCount
        let observedEndIndex = observedWords.count - sharedSuffixCount
        let wrong = originalWords[sharedPrefixCount..<originalEndIndex].joined(separator: " ")
        let right = observedWords[sharedPrefixCount..<observedEndIndex].joined(separator: " ")

        guard !wrong.isEmpty,
              !right.isEmpty,
              wordCount(in: wrong) <= maximumReplacementWordCount,
              wordCount(in: right) <= maximumReplacementWordCount else {
            return nil
        }

        return MisheardReplacement(wrong: wrong, right: right)
    }

    private static func sharedPrefixLength(between lhs: [String], and rhs: [String]) -> Int {
        let limit = min(lhs.count, rhs.count)
        var index = 0
        while index < limit && stringsMatch(lhs[index], rhs[index]) {
            index += 1
        }
        return index
    }

    private static func sharedSuffixLength(
        between lhs: [String],
        and rhs: [String],
        excludingPrefix prefixLength: Int
    ) -> Int {
        let limit = min(lhs.count, rhs.count) - prefixLength
        guard limit > 0 else {
            return 0
        }

        var count = 0
        while count < limit &&
                stringsMatch(lhs[lhs.count - count - 1], rhs[rhs.count - count - 1]) {
            count += 1
        }
        return count
    }

    private static func stringsMatch(_ lhs: String, _ rhs: String) -> Bool {
        lhs.caseInsensitiveCompare(rhs) == .orderedSame
    }

    private static func words(in text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    private static func wordCount(in text: String) -> Int {
        words(in: text).count
    }
}

enum PostPasteLearningObservationProvider {
    static func captureObservation(
        for session: PasteSession,
        customWords: [String],
        locator: FocusedElementLocator = FocusedElementLocator(),
        windowCaptureService: WindowCaptureServing = WindowCaptureService(),
        requestFactory: OCRRequestFactory = OCRRequestFactory()
    ) async -> PostPasteLearningObservation? {
        guard PermissionChecker.hasScreenRecordingPermission(),
              locator.frontmostApplicationBundleIdentifier() == session.frontmostAppBundleIdentifier,
              let currentWindow = locator.frontmostWindowReference(),
              currentWindow.windowID == session.frontmostWindowID,
              let image = try? await windowCaptureService.captureFrontmostWindowImage() else {
            return nil
        }

        let currentFocusedFrame = locator.focusedElementFrame()
        let focusedCrop = focusedCropImage(
            from: image,
            currentWindowFrame: currentWindow.frame,
            session: session,
            currentFocusedFrame: currentFocusedFrame
        )
        let targetImage = focusedCrop ?? image

        guard let result = try? requestFactory.recognizeDetailedText(
            in: targetImage,
            customWords: customWords
        ) else {
            return nil
        }

        return PostPasteLearningObservation(
            recognizedText: result.text,
            confidence: result.confidence
        )
    }

    private static func focusedCropImage(
        from image: CGImage,
        currentWindowFrame: CGRect,
        session: PasteSession,
        currentFocusedFrame: CGRect?
    ) -> CGImage? {
        guard let sessionFocusedFrame = session.focusedElementFrame,
              let currentFocusedFrame,
              currentFocusedFrame.height > 0,
              currentFocusedFrame.width > 0,
              framesApproximatelyMatch(sessionFocusedFrame, currentFocusedFrame) else {
            return nil
        }

        return crop(
            image: image,
            windowFrame: currentWindowFrame,
            targetFrame: currentFocusedFrame
        )
    }

    private static func framesApproximatelyMatch(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        let allowableDeltaX = max(24, lhs.width * 0.2)
        let allowableDeltaY = max(24, lhs.height * 0.2)
        let allowableWidthDelta = max(24, lhs.width * 0.2)
        let allowableHeightDelta = max(24, lhs.height * 0.2)

        return abs(lhs.minX - rhs.minX) <= allowableDeltaX &&
            abs(lhs.minY - rhs.minY) <= allowableDeltaY &&
            abs(lhs.width - rhs.width) <= allowableWidthDelta &&
            abs(lhs.height - rhs.height) <= allowableHeightDelta
    }

    private static func crop(
        image: CGImage,
        windowFrame: CGRect,
        targetFrame: CGRect
    ) -> CGImage? {
        guard windowFrame.width > 0, windowFrame.height > 0 else {
            return nil
        }

        let normalizedRect = CGRect(
            x: (targetFrame.minX - windowFrame.minX) / windowFrame.width,
            y: (targetFrame.minY - windowFrame.minY) / windowFrame.height,
            width: targetFrame.width / windowFrame.width,
            height: targetFrame.height / windowFrame.height
        ).intersection(CGRect(x: 0, y: 0, width: 1, height: 1))

        guard !normalizedRect.isNull,
              normalizedRect.width > 0,
              normalizedRect.height > 0 else {
            return nil
        }

        let cropRect = CGRect(
            x: normalizedRect.minX * CGFloat(image.width),
            y: (1 - normalizedRect.maxY) * CGFloat(image.height),
            width: normalizedRect.width * CGFloat(image.width),
            height: normalizedRect.height * CGFloat(image.height)
        ).integral

        guard cropRect.width > 0, cropRect.height > 0 else {
            return nil
        }

        return image.cropping(to: cropRect)
    }
}
