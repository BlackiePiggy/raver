import { getQuizStatus } from './quiz.service';

export type AccountQualificationItem = {
  key: string;
  type: 'quiz';
  status: 'qualified' | 'unqualified';
  qualifiedAt: string | null;
  summary: string;
  metadata: Record<string, unknown>;
};

export type AccountQualificationSummary = {
  items: AccountQualificationItem[];
};

export const accountQualificationService = {
  async getSummary(userId: string): Promise<AccountQualificationSummary> {
    const quizStatus = await getQuizStatus(userId);

    const quizQualification: AccountQualificationItem = {
      key: 'quiz_pass',
      type: 'quiz',
      status: quizStatus.hasPermanentPass ? 'qualified' : 'unqualified',
      qualifiedAt: quizStatus.passedAt,
      summary: quizStatus.hasPermanentPass ? 'Quiz passed' : 'Quiz not passed',
      metadata: {
        hasPermanentPass: quizStatus.hasPermanentPass,
        passedAt: quizStatus.passedAt,
        canStart: quizStatus.canStart,
        disabledReason: quizStatus.disabledReason,
        questionCount: quizStatus.questionCount,
        passCorrectCount: quizStatus.passCorrectCount,
        todayAttemptCount: quizStatus.todayAttemptCount,
        todayRemainingAttempts: quizStatus.todayRemainingAttempts,
        isUnlimitedAttempts: quizStatus.isUnlimitedAttempts,
        activeSessionId: quizStatus.activeSessionId,
      },
    };

    return {
      items: [quizQualification],
    };
  },
};
