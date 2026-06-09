import 'dotenv/config';

const directDatabaseUrl = process.env.DIRECT_URL || process.env.DATABASE_URL;
if (directDatabaseUrl) {
  process.env.DATABASE_URL = directDatabaseUrl;
}

const assert = (condition: boolean, message: string): void => {
  if (!condition) {
    throw new Error(message);
  }
};

const log = (stage: string, detail?: Record<string, unknown>): void => {
  if (detail) {
    console.log(`[personality-edmti-smoke] ${stage}`, detail);
  } else {
    console.log(`[personality-edmti-smoke] ${stage}`);
  }
};

const TEMP_USER_PREFIX = 'personality_smoke_user_';
const TEMP_EMAIL_DOMAIN = '@local.test';

type SessionAnswer = {
  questionId: string;
  optionId: string | null;
};

const cleanupUserByEmail = async (prisma: any, email: string): Promise<void> => {
  const existing = await prisma.user.findUnique({
    where: { email },
    select: { id: true },
  });
  if (!existing) return;
  await prisma.personalitySession.deleteMany({ where: { userId: existing.id } });
  await prisma.personalityUserRecord.deleteMany({ where: { userId: existing.id } });
  await prisma.user.delete({ where: { id: existing.id } });
};

const ensureTempUser = async (prisma: any, suffix: string): Promise<{ id: string; email: string }> => {
  const email = `${TEMP_USER_PREFIX}${suffix}${TEMP_EMAIL_DOMAIN}`;
  await cleanupUserByEmail(prisma, email);
  const created = await prisma.user.create({
    data: {
      email,
      username: `${TEMP_USER_PREFIX}${suffix}`,
      passwordHash: 'personality-edmti-smoke-password-hash',
      displayName: `Personality Smoke ${suffix}`,
      role: 'user',
    },
    select: { id: true, email: true },
  });
  return created;
};

const buildAnswerBySortOrder = (
  questions: Array<{
    questionId: string;
    isEasterEgg: boolean;
    options: Array<{ optionId: string; text: string | null }>;
  }>,
  mapping: Record<number, number>
): SessionAnswer[] => {
  return questions.map((question, index) => {
    const optionIndex = mapping[index + 1];
    const option = typeof optionIndex === 'number' ? question.options[optionIndex] : question.options[0];
    return {
      questionId: question.questionId,
      optionId: option?.optionId ?? null,
    };
  });
};

const main = async (): Promise<void> => {
  const { PrismaClient } = await import('@prisma/client');
  const {
    createPersonalitySession,
    submitPersonalitySession,
  } = await import('../services/personality.service');

  const prisma = new PrismaClient();

  const createdUsers: Array<{ id: string; email: string }> = [];
  let originalEnabled: boolean | null = null;

  try {
    log('boot');

    const config = await prisma.personalityConfig.findUnique({ where: { id: 'default' } });
    assert(Boolean(config), 'personality config should exist');
    assert((config?.standardQuestionIds.length ?? 0) === 16, 'standardQuestionIds should contain 16 items');
    assert(Boolean(config?.easterEggQuestionId), 'easterEggQuestionId should exist');
    originalEnabled = Boolean(config?.isEnabled);
    if (!config?.isEnabled) {
      await prisma.personalityConfig.update({
        where: { id: 'default' },
        data: { isEnabled: true },
      });
      log('config:temporarily-enabled');
    }

    const runCase = async (
      suffix: string,
      input: {
        mapping: Record<number, number>;
        expectedCode: string;
      }
    ) => {
      const user = await ensureTempUser(prisma, suffix);
      createdUsers.push(user);

      const session = await createPersonalitySession(user.id, { mode: 'standard', userRole: 'user' });
      assert(session.questions.length === 17, `${suffix}: expected 17 questions in session`);
      const answers = buildAnswerBySortOrder(session.questions, input.mapping);
      const result = await submitPersonalitySession(user.id, session.sessionId, answers);
      assert(result.result.code === input.expectedCode, `${suffix}: expected ${input.expectedCode}, got ${result.result.code}`);
      log(`case:${suffix}:passed`, {
        resultCode: result.result.code,
        axisScores: result.axisScores,
        balanceScores: result.balanceScores,
      });
    };

    await runCase('bomb', {
      expectedCode: 'BOMB',
      mapping: {
        1: 2,
        2: 2,
        3: 0,
        4: 2,
        5: 2,
        6: 2,
        7: 0,
        8: 2,
        9: 2,
        10: 0,
        11: 2,
        12: 0,
        13: 2,
        14: 0,
        15: 0,
        16: 0,
        17: 0,
      },
    });

    await runCase('phoenix', {
      expectedCode: 'PHOENIX',
      mapping: {
        1: 2,
        2: 2,
        3: 0,
        4: 2,
        5: 2,
        6: 2,
        7: 4,
        8: 2,
        9: 2,
        10: 0,
        11: 2,
        12: 0,
        13: 2,
        14: 0,
        15: 0,
        16: 0,
        17: 0,
      },
    });

    await runCase('drunk', {
      expectedCode: 'DRUNK',
      mapping: {
        1: 2,
        2: 2,
        3: 0,
        4: 2,
        5: 2,
        6: 2,
        7: 0,
        8: 2,
        9: 2,
        10: 0,
        11: 2,
        12: 0,
        13: 2,
        14: 0,
        15: 0,
        16: 0,
        17: 2,
      },
    });

    await runCase('cpdd', {
      expectedCode: 'CPDD',
      mapping: {
        1: 2,
        2: 2,
        3: 0,
        4: 2,
        5: 2,
        6: 2,
        7: 0,
        8: 2,
        9: 2,
        10: 0,
        11: 2,
        12: 0,
        13: 2,
        14: 0,
        15: 0,
        16: 0,
        17: 3,
      },
    });

    log('passed');
  } catch (error) {
    console.error('[personality-edmti-smoke] failed', error);
    process.exitCode = 1;
  } finally {
    if (originalEnabled === false) {
      try {
        await prisma.personalityConfig.update({
          where: { id: 'default' },
          data: { isEnabled: false },
        });
      } catch (restoreError) {
        console.error('[personality-edmti-smoke] config restore failed', restoreError);
        process.exitCode = 1;
      }
    }
    for (const user of createdUsers) {
      try {
        await cleanupUserByEmail(prisma, user.email);
      } catch (cleanupError) {
        console.error('[personality-edmti-smoke] cleanup failed', { email: user.email, cleanupError });
        process.exitCode = 1;
      }
    }
    await prisma.$disconnect();
  }
};

void main();
