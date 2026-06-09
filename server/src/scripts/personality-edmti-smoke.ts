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

const buildAnswerByStemMap = (
  questions: Array<{
    questionId: string;
    stemText: string;
    isEasterEgg: boolean;
    options: Array<{ optionId: string; text: string | null }>;
  }>,
  mapping: Record<string, number>
): SessionAnswer[] => {
  return questions.map((question) => {
    const optionIndex = mapping[question.stemText];
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
        mapping: Record<string, number>;
        expectedCode: string;
      }
    ) => {
      const user = await ensureTempUser(prisma, suffix);
      createdUsers.push(user);

      const session = await createPersonalitySession(user.id, { mode: 'standard', userRole: 'user' });
      assert(session.questions.length === 17, `${suffix}: expected 17 questions in session`);
      const answers = buildAnswerByStemMap(session.questions, input.mapping);
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
        '深夜独处放空时，你的耳机专属 BGM 会偏向哪种？': 2,
        '去电音节，你最真实的状态是？': 2,
        '关于你的私人歌单，日常状态更贴合？': 0,
        '刷到爆红的网红电音曲目，你的第一反应是？': 2,
        '生活压力爆棚、情绪烦躁时，电音对你而言是？': 2,
        '挖到一首本命神仙电音，你会如何分享这份快乐？': 2,
        '对待听歌审美，你的一贯态度是？': 0,
        '挑选常驻单曲的核心标准，你更看重？': 2,
        '线下奔赴电音现场，你的核心诉求是？': 2,
        '聆听一首完整电音，你最偏爱哪个段落？': 0,
        '周末松弛休憩，你的电音放松模式是？': 2,
        '长期听歌习惯里，你更倾向于？': 0,
        '你的歌单主力曲风更贴近？': 2,
        '电音带给你的核心情绪价值是？': 0,
        '播放模式的常年选择是？': 0,
        '面对全新电音作品，你的接纳姿态是？': 0,
        '去电音节/夜店，你的核心终极目的是？': 0,
      },
    });

    await runCase('phoenix', {
      expectedCode: 'PHOENIX',
      mapping: {
        '深夜独处放空时，你的耳机专属 BGM 会偏向哪种？': 2,
        '去电音节，你最真实的状态是？': 2,
        '关于你的私人歌单，日常状态更贴合？': 0,
        '刷到爆红的网红电音曲目，你的第一反应是？': 2,
        '生活压力爆棚、情绪烦躁时，电音对你而言是？': 2,
        '挖到一首本命神仙电音，你会如何分享这份快乐？': 2,
        '对待听歌审美，你的一贯态度是？': 4,
        '挑选常驻单曲的核心标准，你更看重？': 2,
        '线下奔赴电音现场，你的核心诉求是？': 2,
        '聆听一首完整电音，你最偏爱哪个段落？': 0,
        '周末松弛休憩，你的电音放松模式是？': 2,
        '长期听歌习惯里，你更倾向于？': 0,
        '你的歌单主力曲风更贴近？': 2,
        '电音带给你的核心情绪价值是？': 0,
        '播放模式的常年选择是？': 0,
        '面对全新电音作品，你的接纳姿态是？': 0,
        '去电音节/夜店，你的核心终极目的是？': 0,
      },
    });

    await runCase('drunk', {
      expectedCode: 'DRUNK',
      mapping: {
        '深夜独处放空时，你的耳机专属 BGM 会偏向哪种？': 2,
        '去电音节，你最真实的状态是？': 2,
        '关于你的私人歌单，日常状态更贴合？': 0,
        '刷到爆红的网红电音曲目，你的第一反应是？': 2,
        '生活压力爆棚、情绪烦躁时，电音对你而言是？': 2,
        '挖到一首本命神仙电音，你会如何分享这份快乐？': 2,
        '对待听歌审美，你的一贯态度是？': 0,
        '挑选常驻单曲的核心标准，你更看重？': 2,
        '线下奔赴电音现场，你的核心诉求是？': 2,
        '聆听一首完整电音，你最偏爱哪个段落？': 0,
        '周末松弛休憩，你的电音放松模式是？': 2,
        '长期听歌习惯里，你更倾向于？': 0,
        '你的歌单主力曲风更贴近？': 2,
        '电音带给你的核心情绪价值是？': 0,
        '播放模式的常年选择是？': 0,
        '面对全新电音作品，你的接纳姿态是？': 0,
        '去电音节/夜店，你的核心终极目的是？': 2,
      },
    });

    await runCase('cpdd', {
      expectedCode: 'CPDD',
      mapping: {
        '深夜独处放空时，你的耳机专属 BGM 会偏向哪种？': 2,
        '去电音节，你最真实的状态是？': 2,
        '关于你的私人歌单，日常状态更贴合？': 0,
        '刷到爆红的网红电音曲目，你的第一反应是？': 2,
        '生活压力爆棚、情绪烦躁时，电音对你而言是？': 2,
        '挖到一首本命神仙电音，你会如何分享这份快乐？': 2,
        '对待听歌审美，你的一贯态度是？': 0,
        '挑选常驻单曲的核心标准，你更看重？': 2,
        '线下奔赴电音现场，你的核心诉求是？': 2,
        '聆听一首完整电音，你最偏爱哪个段落？': 0,
        '周末松弛休憩，你的电音放松模式是？': 2,
        '长期听歌习惯里，你更倾向于？': 0,
        '你的歌单主力曲风更贴近？': 2,
        '电音带给你的核心情绪价值是？': 0,
        '播放模式的常年选择是？': 0,
        '面对全新电音作品，你的接纳姿态是？': 0,
        '去电音节/夜店，你的核心终极目的是？': 3,
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
