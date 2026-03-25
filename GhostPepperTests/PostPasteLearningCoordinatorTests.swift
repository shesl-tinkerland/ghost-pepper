import XCTest
@testable import GhostPepper

@MainActor
final class PostPasteLearningCoordinatorTests: XCTestCase {
    func testCoordinatorStartsLearningPassAfterPasteDelay() async throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: #function))
        defaults.removePersistentDomain(forName: #function)
        let correctionStore = CorrectionStore(defaults: defaults)
        var scheduledDelay: TimeInterval?
        var scheduledWork: (() -> Void)?
        var revisitCallCount = 0
        let coordinator = PostPasteLearningCoordinator(
            correctionStore: correctionStore,
            scheduler: { delay, work in
                scheduledDelay = delay
                scheduledWork = work
            },
            revisit: { _ in
                revisitCallCount += 1
                return nil
            }
        )

        coordinator.handlePaste(samplePasteSession())

        XCTAssertEqual(scheduledDelay, PostPasteLearningCoordinator.learningDelay)
        XCTAssertEqual(revisitCallCount, 0)

        scheduledWork?()
        await waitUntil { revisitCallCount == 1 }

        XCTAssertEqual(revisitCallCount, 1)
    }

    func testCoordinatorRejectsLargeRewriteDiffs() async throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: #function))
        defaults.removePersistentDomain(forName: #function)
        let correctionStore = CorrectionStore(defaults: defaults)
        var scheduledWork: (() -> Void)?
        let coordinator = PostPasteLearningCoordinator(
            correctionStore: correctionStore,
            scheduler: { _, work in scheduledWork = work },
            revisit: { _ in
                PostPasteLearningObservation(
                    recognizedText: "This sentence was rewritten into something unrelated",
                    confidence: 0.99
                )
            }
        )

        coordinator.handlePaste(samplePasteSession())
        scheduledWork?()
        await Task.yield()

        XCTAssertTrue(correctionStore.commonlyMisheard.isEmpty)
    }

    func testCoordinatorStoresHighConfidenceNarrowReplacement() async throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: #function))
        defaults.removePersistentDomain(forName: #function)
        let correctionStore = CorrectionStore(defaults: defaults)
        var scheduledWork: (() -> Void)?
        let coordinator = PostPasteLearningCoordinator(
            correctionStore: correctionStore,
            scheduler: { _, work in scheduledWork = work },
            revisit: { _ in
                PostPasteLearningObservation(
                    recognizedText: "Jesse approved it",
                    confidence: 0.99
                )
            }
        )

        coordinator.handlePaste(samplePasteSession())
        scheduledWork?()
        await waitUntil {
            correctionStore.commonlyMisheard == [MisheardReplacement(wrong: "just see", right: "Jesse")]
        }

        XCTAssertEqual(
            correctionStore.commonlyMisheard,
            [MisheardReplacement(wrong: "just see", right: "Jesse")]
        )
    }

    func testCoordinatorUsesInjectedSchedulerInsteadOfRealSleep() {
        let correctionStore = CorrectionStore(defaults: UserDefaults(suiteName: #function)!)
        var scheduledDelay: TimeInterval?
        var scheduledWork: (() -> Void)?
        let coordinator = PostPasteLearningCoordinator(
            correctionStore: correctionStore,
            scheduler: { delay, work in
                scheduledDelay = delay
                scheduledWork = work
            },
            revisit: { _ in
                XCTFail("Revisit should not run until the test triggers the scheduled work")
                return nil
            }
        )

        coordinator.handlePaste(samplePasteSession())

        XCTAssertEqual(scheduledDelay, PostPasteLearningCoordinator.learningDelay)
        XCTAssertNotNil(scheduledWork)
    }

    func testCoordinatorDoesNotScheduleWhenLearningIsDisabled() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: #function))
        defaults.removePersistentDomain(forName: #function)
        let correctionStore = CorrectionStore(defaults: defaults)
        var scheduledWork: (() -> Void)?
        let coordinator = PostPasteLearningCoordinator(
            correctionStore: correctionStore,
            learningEnabled: false,
            scheduler: { _, work in
                scheduledWork = work
            },
            revisit: { _ in
                XCTFail("Disabled learning should not trigger OCR revisit")
                return nil
            }
        )

        coordinator.handlePaste(samplePasteSession())

        XCTAssertNil(scheduledWork)
        XCTAssertTrue(correctionStore.commonlyMisheard.isEmpty)
    }

    func testCoordinatorRejectsLowConfidenceObservation() async throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: #function))
        defaults.removePersistentDomain(forName: #function)
        let correctionStore = CorrectionStore(defaults: defaults)
        var scheduledWork: (() -> Void)?
        let coordinator = PostPasteLearningCoordinator(
            correctionStore: correctionStore,
            scheduler: { _, work in scheduledWork = work },
            revisit: { _ in
                PostPasteLearningObservation(
                    recognizedText: "Jesse approved it",
                    confidence: 0.6
                )
            }
        )

        coordinator.handlePaste(samplePasteSession())
        scheduledWork?()
        await Task.yield()

        XCTAssertTrue(correctionStore.commonlyMisheard.isEmpty)
    }

    func testCoordinatorLogsScheduledAndLearnedCorrection() async throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: #function))
        defaults.removePersistentDomain(forName: #function)
        let correctionStore = CorrectionStore(defaults: defaults)
        var scheduledWork: (() -> Void)?
        var debugMessages: [String] = []
        let coordinator = PostPasteLearningCoordinator(
            correctionStore: correctionStore,
            scheduler: { _, work in scheduledWork = work },
            revisit: { _ in
                PostPasteLearningObservation(
                    recognizedText: "Jesse approved it",
                    confidence: 0.99
                )
            }
        )
        coordinator.debugLogger = { _, message in
            debugMessages.append(message)
        }

        coordinator.handlePaste(samplePasteSession())
        scheduledWork?()
        await waitUntil {
            correctionStore.commonlyMisheard == [MisheardReplacement(wrong: "just see", right: "Jesse")]
        }

        XCTAssertTrue(debugMessages.contains(where: { $0.contains("Scheduled post-paste learning revisit") }))
        XCTAssertTrue(debugMessages.contains(where: { $0.contains("Post-paste learning learned replacement: just see -> Jesse") }))
    }

    func testCoordinatorLogsWhyLearningSkipped() async throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: #function))
        defaults.removePersistentDomain(forName: #function)
        let correctionStore = CorrectionStore(defaults: defaults)
        var scheduledWork: (() -> Void)?
        var debugMessages: [String] = []
        let coordinator = PostPasteLearningCoordinator(
            correctionStore: correctionStore,
            scheduler: { _, work in scheduledWork = work },
            revisit: { _ in
                PostPasteLearningObservation(
                    recognizedText: "Jesse approved it",
                    confidence: 0.6
                )
            }
        )
        coordinator.debugLogger = { _, message in
            debugMessages.append(message)
        }

        coordinator.handlePaste(samplePasteSession())
        scheduledWork?()
        await Task.yield()

        XCTAssertTrue(debugMessages.contains(where: { $0.contains("Post-paste learning skipped because OCR confidence") }))
    }

    private func samplePasteSession() -> PasteSession {
        PasteSession(
            pastedText: "just see approved it",
            pastedAt: Date(timeIntervalSince1970: 1_742_751_200),
            frontmostAppBundleIdentifier: "com.example.app",
            frontmostWindowID: 42,
            frontmostWindowFrame: CGRect(x: 10, y: 20, width: 800, height: 600),
            focusedElementFrame: CGRect(x: 20, y: 40, width: 300, height: 120)
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 0.5,
        condition: @escaping @Sendable () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return
            }

            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}
