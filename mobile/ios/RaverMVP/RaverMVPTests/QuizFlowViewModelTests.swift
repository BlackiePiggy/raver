import XCTest
import SwiftUI
@testable import RaverMVP

@MainActor
final class QuizFlowViewModelTests: XCTestCase {
    func testCountdownTimeoutAutoAdvancesAndSubmits() async throws {
        let service = MockWebFeatureService()
        await service.setQuizScenario(
            .init(
                status: Self.defaultSummary(),
                sessionFactory: {
                    QuizSessionCreateResponse(
                        sessionId: "quiz-session-timeout",
                        questionCount: 1,
                        passCorrectCount: 1,
                        dailyAttemptLimit: 3,
                        dailyRemainingAttemptsAfterStart: 2,
                        timeZone: "Asia/Shanghai",
                        questions: [
                            QuizQuestionPayload(
                                questionId: "q1",
                                stemText: "timeout question",
                                stemImageUrl: nil,
                                options: [
                                    QuizQuestionOptionPayload(optionId: "q1-a", text: "A", imageUrl: nil, sortOrder: 0),
                                    QuizQuestionOptionPayload(optionId: "q1-b", text: "B", imageUrl: nil, sortOrder: 1),
                                ],
                                timeLimitSec: 1
                            )
                        ],
                        startedAt: ISO8601DateFormatter().string(from: Date()),
                        expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))
                    )
                },
                submitHandler: { sessionId, answers in
                    XCTAssertEqual(sessionId, "quiz-session-timeout")
                    XCTAssertEqual(answers.count, 1)
                    XCTAssertNil(answers.first?.optionId)
                    return QuizSessionSubmitResponse(
                        sessionId: sessionId,
                        totalCount: 1,
                        correctCount: 0,
                        passCorrectCount: 1,
                        passed: false,
                        passedAt: nil
                    )
                },
                abandonHandler: { sessionId in
                    QuizSessionAbandonResponse(sessionId: sessionId, status: "abandoned")
                }
            )
        )

        let viewModel = QuizFlowViewModel(
            service: service,
            countdownTickNanoseconds: 20_000_000,
            mediaRetryDelayNanoseconds: 1_000_000
        )

        await viewModel.startQuiz()
        XCTAssertFalse(viewModel.isPreparingQuestion)

        try await Task.sleep(nanoseconds: 120_000_000)

        guard case .result(let result) = viewModel.phase else {
            return XCTFail("expected quiz result after timeout")
        }
        XCTAssertEqual(result.correctCount, 0)
        XCTAssertFalse(result.passed)
        XCTAssertEqual(viewModel.feedbackMessage, LT(
            "本题已超时，系统已自动判错并进入下一题。",
            "Time is up for this question. It was marked wrong automatically.",
            "この問題は時間切れとなり、自動で不正解として次へ進みました。"
        ))
    }

    func testMediaPreloadCompletesBeforeCountdownStarts() async throws {
        let service = MockWebFeatureService()
        let preloadStarted = expectation(description: "preload started")
        let gate = PreloadGate()

        let viewModel = QuizFlowViewModel(
            service: service,
            countdownTickNanoseconds: 20_000_000,
            mediaRetryDelayNanoseconds: 1_000_000,
            mediaPreloader: { urls in
                XCTAssertEqual(urls.count, 2)
                preloadStarted.fulfill()
                await gate.wait()
            }
        )

        await service.setQuizScenario(
            .init(
                status: Self.defaultSummary(),
                sessionFactory: {
                    QuizSessionCreateResponse(
                        sessionId: "quiz-session-preload",
                        questionCount: 1,
                        passCorrectCount: 1,
                        dailyAttemptLimit: 3,
                        dailyRemainingAttemptsAfterStart: 2,
                        timeZone: "Asia/Shanghai",
                        questions: [
                            QuizQuestionPayload(
                                questionId: "q-preload",
                                stemText: "preload question",
                                stemImageUrl: "https://example.com/stem.jpg",
                                options: [
                                    QuizQuestionOptionPayload(optionId: "opt-a", text: "A", imageUrl: "https://example.com/opt-a.jpg", sortOrder: 0),
                                    QuizQuestionOptionPayload(optionId: "opt-b", text: "B", imageUrl: nil, sortOrder: 1),
                                ],
                                timeLimitSec: 3
                            )
                        ],
                        startedAt: ISO8601DateFormatter().string(from: Date()),
                        expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))
                    )
                },
                submitHandler: { sessionId, _ in
                    QuizSessionSubmitResponse(
                        sessionId: sessionId,
                        totalCount: 1,
                        correctCount: 0,
                        passCorrectCount: 1,
                        passed: false,
                        passedAt: nil
                    )
                },
                abandonHandler: { sessionId in
                    QuizSessionAbandonResponse(sessionId: sessionId, status: "abandoned")
                }
            )
        )

        let startTask = Task { await viewModel.startQuiz() }
        await fulfillment(of: [preloadStarted], timeout: 1.0)

        XCTAssertTrue(viewModel.isPreparingQuestion)
        XCTAssertEqual(viewModel.secondsRemaining, 0)

        await gate.open()
        await startTask.value

        XCTAssertFalse(viewModel.isPreparingQuestion)
        XCTAssertEqual(viewModel.secondsRemaining, 3)
    }

    func testBackgroundAbandonsSessionAndReturnsToReady() async throws {
        let service = MockWebFeatureService()
        let abandonedSession = LockedBox<[String]>([])

        await service.setQuizScenario(
            .init(
                status: Self.defaultSummary(),
                sessionFactory: {
                    QuizSessionCreateResponse(
                        sessionId: "quiz-session-background",
                        questionCount: 1,
                        passCorrectCount: 1,
                        dailyAttemptLimit: 3,
                        dailyRemainingAttemptsAfterStart: 2,
                        timeZone: "Asia/Shanghai",
                        questions: [
                            QuizQuestionPayload(
                                questionId: "q-background",
                                stemText: "background question",
                                stemImageUrl: nil,
                                options: [
                                    QuizQuestionOptionPayload(optionId: "opt-a", text: "A", imageUrl: nil, sortOrder: 0),
                                    QuizQuestionOptionPayload(optionId: "opt-b", text: "B", imageUrl: nil, sortOrder: 1),
                                ],
                                timeLimitSec: 5
                            )
                        ],
                        startedAt: ISO8601DateFormatter().string(from: Date()),
                        expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))
                    )
                },
                submitHandler: { sessionId, _ in
                    QuizSessionSubmitResponse(
                        sessionId: sessionId,
                        totalCount: 1,
                        correctCount: 0,
                        passCorrectCount: 1,
                        passed: false,
                        passedAt: nil
                    )
                },
                abandonHandler: { sessionId in
                    abandonedSession.mutate { $0.append(sessionId) }
                    return QuizSessionAbandonResponse(sessionId: sessionId, status: "abandoned")
                }
            )
        )

        let viewModel = QuizFlowViewModel(
            service: service,
            countdownTickNanoseconds: 20_000_000,
            mediaRetryDelayNanoseconds: 1_000_000
        )

        await viewModel.startQuiz()
        XCTAssertNotNil(viewModel.session)

        await viewModel.handleScenePhaseChange(.background)

        XCTAssertEqual(abandonedSession.value, ["quiz-session-background"])
        XCTAssertNil(viewModel.session)
        guard case .ready = viewModel.phase else {
            return XCTFail("expected ready phase after background abandon")
        }
        XCTAssertEqual(viewModel.feedbackMessage, LT(
            "答题过程中切到后台，本次答题已自动作废，需要重新开始。",
            "The quiz was sent to the background and has been abandoned. Please restart.",
            "クイズ中にアプリがバックグラウンドへ移動したため、この回は破棄されました。再度開始してください。"
        ))
    }

    private static func defaultSummary() -> QuizConfigSummary {
        QuizConfigSummary(
            isEnabled: true,
            questionCount: 20,
            passCorrectCount: 16,
            dailyAttemptLimit: 3,
            effectiveDailyAttemptLimit: 3,
            isUnlimitedAttempts: false,
            attemptMode: "default",
            defaultTimeLimitSec: 20,
            dailyLimitTimeZone: "Asia/Shanghai",
            allowRetakeAfterPass: true,
            allowRestartDuringSession: true,
            todayAttemptCount: 0,
            todayRemainingAttempts: 3,
            hasPermanentPass: false,
            passedAt: nil,
            canStart: true,
            activeSessionId: nil,
            disabledReason: nil
        )
    }
}

private actor PreloadGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isOpen = false

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func open() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}

private final class LockedBox<Value> {
    private let lock = NSLock()
    private var storage: Value

    init(_ value: Value) {
        storage = value
    }

    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func mutate(_ update: (inout Value) -> Void) {
        lock.lock()
        update(&storage)
        lock.unlock()
    }
}
