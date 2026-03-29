import XCTest
@testable import GhostPepper

@MainActor
final class RuntimeModelInventoryTests: XCTestCase {
    func testRuntimeModelRowsIncludeAllSpeechAndCleanupModels() {
        let rows = RuntimeModelInventory.rows(
            selectedSpeechModelName: "openai_whisper-small.en",
            activeSpeechModelName: "openai_whisper-small.en",
            speechModelState: .loading,
            speechDownloadProgress: nil,
            cachedSpeechModelNames: ["openai_whisper-tiny.en"],
            cleanupState: .downloading(kind: .qwen35_4b_q4_k_m, progress: 0.4),
            selectedCleanupModelKind: .qwen35_4b_q4_k_m,
            cachedCleanupKinds: [.qwen35_0_8b_q4_k_m, .qwen35_2b_q4_k_m]
        )

        XCTAssertEqual(rows.map(\.name), [
            "Whisper tiny.en (speed)",
            "Whisper small.en (accuracy)",
            "Whisper small (multilingual)",
            "Parakeet v3 (25 languages)",
            "Qwen 3.5 0.8B Q4_K_M (Very fast)",
            "Qwen 3.5 2B Q4_K_M (Fast)",
            "Qwen 3.5 4B Q4_K_M (Full)",
        ])

        XCTAssertEqual(rows[0].status, .loaded)
        XCTAssertFalse(rows[0].isSelected)

        XCTAssertEqual(rows[1].status, .downloading(progress: nil))
        XCTAssertTrue(rows[1].isSelected)

        XCTAssertEqual(rows[2].status, .notLoaded)
        XCTAssertFalse(rows[2].isSelected)

        XCTAssertEqual(rows[3].status, .notLoaded)
        XCTAssertFalse(rows[3].isSelected)

        XCTAssertEqual(rows[4].status, .loaded)
        XCTAssertFalse(rows[4].isSelected)

        XCTAssertEqual(rows[5].status, .loaded)
        XCTAssertFalse(rows[5].isSelected)

        XCTAssertEqual(rows[6].status, .downloading(progress: 0.4))
        XCTAssertFalse(rows[6].isSelected)
    }

    func testRuntimeModelRowsSeparateSelectedSpeechModelFromActiveDownload() {
        let rows = RuntimeModelInventory.rows(
            selectedSpeechModelName: "openai_whisper-small.en",
            activeSpeechModelName: "openai_whisper-tiny.en",
            speechModelState: .loading,
            speechDownloadProgress: nil,
            cachedSpeechModelNames: [],
            cleanupState: .idle,
            selectedCleanupModelKind: .qwen35_2b_q4_k_m,
            cachedCleanupKinds: []
        )

        XCTAssertEqual(rows[0].status, .downloading(progress: nil))
        XCTAssertFalse(rows[0].isSelected)

        XCTAssertEqual(rows[1].status, .notLoaded)
        XCTAssertTrue(rows[1].isSelected)
    }

    func testRuntimeModelRowsShowCachedSpeechModelAsLoadingInsteadOfDownloading() {
        let rows = RuntimeModelInventory.rows(
            selectedSpeechModelName: "openai_whisper-small.en",
            activeSpeechModelName: "openai_whisper-small.en",
            speechModelState: .loading,
            speechDownloadProgress: nil,
            cachedSpeechModelNames: ["openai_whisper-small.en"],
            cleanupState: .idle,
            selectedCleanupModelKind: .qwen35_2b_q4_k_m,
            cachedCleanupKinds: []
        )

        XCTAssertEqual(rows[1].status, .loading)
        XCTAssertNil(RuntimeModelInventory.activeDownloadText(rows: rows))
    }
}
