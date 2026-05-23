import { Prisma, PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export type DJEventBindingTriggerSource =
  | 'admin_create'
  | 'manual_import'
  | 'content_submission_approved'
  | 'migration';

type CandidateMatchTier = 'exact' | 'fuzzy';
type CandidateSourceType = 'lineup_artist' | 'lineup_member' | 'timetable_slot';
type CandidateMatchReason = 'normalized_equal' | 'compact_equal' | 'contains' | 'similarity';

type CandidateDraft = {
  djId: string;
  eventId: string;
  eventArtistId: string | null;
  eventArtistMemberId: string | null;
  eventPerformanceId: string | null;
  sourceType: CandidateSourceType;
  matchTier: CandidateMatchTier;
  matchScore: number;
  matchReason: CandidateMatchReason;
  rawName: string;
  normalizedKey: string;
  compactKey: string;
  eventNameSnapshot: string;
  stageNameSnapshot: string | null;
  startAtSnapshot: Date | null;
  needsSplit: boolean;
};

type DJLookupKeys = {
  normalizedKeys: Set<string>;
  compactKeys: Set<string>;
};

type ListDJEventBindingReviewJobsInput = {
  status?: string;
  page?: number;
  limit?: number;
};

const REVIEW_JOB_INCLUDE = {
  dj: {
    select: {
      id: true,
      name: true,
      avatarUrl: true,
    },
  },
  candidates: {
    orderBy: [{ matchTier: 'asc' }, { matchScore: 'desc' }, { createdAt: 'asc' }],
  },
} satisfies Prisma.DJEventBindingReviewJobInclude;

const normalizeSpaces = (value: string): string => value.replace(/\s+/g, ' ').trim();

const stripDiacritics = (value: string): string =>
  value.normalize('NFKD').replace(/[\u0300-\u036f]/g, '');

export const normalizeDJBindingName = (value: string): string => {
  const text = normalizeSpaces(String(value || ''));
  if (!text) return '';
  return normalizeSpaces(
    stripDiacritics(text.normalize('NFKC').toLowerCase())
      .replace(/[。·•_\-–—/\\,，:：.]/g, ' ')
  );
};

export const compactDJBindingName = (value: string): string =>
  normalizeDJBindingName(value).replace(/\s+/g, '');

const containsLettersOrCJK = (value: string): boolean => /[a-z\u4e00-\u9fff]/i.test(value);

const buildDJLookupKeys = (dj: {
  name: string;
  aliases: string[];
  nameI18n: Prisma.JsonValue | null;
}): DJLookupKeys => {
  const candidates = new Set<string>();
  const add = (raw: unknown) => {
    if (typeof raw !== 'string') return;
    const trimmed = raw.trim();
    if (!trimmed) return;
    candidates.add(trimmed);
  };

  add(dj.name);
  (dj.aliases || []).forEach(add);

  if (dj.nameI18n && typeof dj.nameI18n === 'object' && !Array.isArray(dj.nameI18n)) {
    const row = dj.nameI18n as Record<string, unknown>;
    add(row.zh);
    add(row.en);
    add(row.ja);
    add(row.enFull);
  }

  const normalizedKeys = new Set<string>();
  const compactKeys = new Set<string>();
  for (const candidate of candidates) {
    const normalized = normalizeDJBindingName(candidate);
    const compact = compactDJBindingName(candidate);
    if (normalized) normalizedKeys.add(normalized);
    if (compact) compactKeys.add(compact);
  }

  return { normalizedKeys, compactKeys };
};

const stringSimilarity = (left: string, right: string): number => {
  const a = left.trim();
  const b = right.trim();
  if (!a || !b) return 0;
  if (a === b) return 1;

  const longer = a.length >= b.length ? a : b;
  const shorter = a.length >= b.length ? b : a;
  const longerLength = longer.length;
  if (longerLength === 0) return 1;

  const costs = Array(shorter.length + 1).fill(0);
  for (let j = 0; j <= shorter.length; j += 1) costs[j] = j;

  for (let i = 1; i <= longer.length; i += 1) {
    let previous = i;
    for (let j = 1; j <= shorter.length; j += 1) {
      const current = costs[j];
      const substitution = longer[i - 1] === shorter[j - 1] ? costs[j - 1] : costs[j - 1] + 1;
      const insertion = previous + 1;
      const deletion = current + 1;
      costs[j - 1] = previous;
      previous = Math.min(insertion, deletion, substitution);
    }
    costs[shorter.length] = previous;
  }

  const distance = costs[shorter.length];
  return (longerLength - distance) / longerLength;
};

const classifyCandidate = (
  rawName: string,
  keys: DJLookupKeys
): { tier: CandidateMatchTier; score: number; reason: CandidateMatchReason } | null => {
  const normalized = normalizeDJBindingName(rawName);
  const compact = compactDJBindingName(rawName);
  if (!normalized) return null;

  if (keys.normalizedKeys.has(normalized)) {
    return { tier: 'exact', score: 100, reason: 'normalized_equal' };
  }

  if (
    compact &&
    compact.length >= 4 &&
    containsLettersOrCJK(compact) &&
    keys.compactKeys.has(compact)
  ) {
    return { tier: 'exact', score: 96, reason: 'compact_equal' };
  }

  let bestScore = 0;
  let bestReason: CandidateMatchReason | null = null;

  for (const normalizedKey of keys.normalizedKeys) {
    if (!normalizedKey) continue;
    if (normalized.includes(normalizedKey) || normalizedKey.includes(normalized)) {
      bestScore = Math.max(bestScore, 88);
      bestReason = bestReason ?? 'contains';
    }
    bestScore = Math.max(bestScore, Math.round(stringSimilarity(normalized, normalizedKey) * 100));
    if (bestScore >= 86) {
      bestReason = bestReason ?? 'similarity';
    }
  }

  for (const compactKey of keys.compactKeys) {
    if (!compact || !compactKey) continue;
    if (compact.includes(compactKey) || compactKey.includes(compact)) {
      bestScore = Math.max(bestScore, 87);
      bestReason = bestReason ?? 'contains';
    }
    bestScore = Math.max(bestScore, Math.round(stringSimilarity(compact, compactKey) * 100));
    if (bestScore >= 86) {
      bestReason = bestReason ?? 'similarity';
    }
  }

  if (bestScore >= 92) {
    return { tier: 'fuzzy', score: bestScore, reason: bestReason ?? 'similarity' };
  }
  if (bestScore >= 86) {
    return { tier: 'fuzzy', score: bestScore, reason: bestReason ?? 'similarity' };
  }
  return null;
};

const buildCandidateDedupKey = (candidate: CandidateDraft): string =>
  [
    candidate.eventId,
    candidate.eventArtistId ?? '',
    candidate.eventArtistMemberId ?? '',
    candidate.eventPerformanceId ?? '',
    candidate.rawName,
    candidate.matchTier,
  ].join('::');

const computeJobStatus = (job: {
  exactCount: number;
  fuzzyCount: number;
  appliedCount: number;
  candidates: Array<{ status: string }>;
}): 'pending' | 'partially_applied' | 'applied' | 'dismissed' => {
  const total = job.exactCount + job.fuzzyCount;
  const pendingCount = job.candidates.filter((candidate) => candidate.status === 'pending').length;
  const appliedCount = job.candidates.filter((candidate) => candidate.status === 'applied').length;

  if (total === 0) return 'dismissed';
  if (pendingCount === 0 && appliedCount === 0) return 'dismissed';
  if (pendingCount === 0 && appliedCount > 0) return 'applied';
  if (appliedCount > 0) return 'partially_applied';
  return 'pending';
};

async function loadCandidateUniverse() {
  const [artists, performances] = await Promise.all([
    prisma.eventArtist.findMany({
      where: {
        primaryDjId: null,
      },
      select: {
        id: true,
        displayName: true,
        eventId: true,
        event: {
          select: {
            id: true,
            name: true,
            startDate: true,
          },
        },
        members: {
          where: {
            djId: null,
          },
          select: {
            id: true,
            memberNameSnapshot: true,
          },
          orderBy: { memberOrder: 'asc' },
        },
      },
      orderBy: [{ createdAt: 'desc' }],
    }),
    prisma.eventPerformance.findMany({
      where: {
        eventArtist: {
          primaryDjId: null,
        },
      },
      select: {
        id: true,
        displayNameSnapshot: true,
        startAt: true,
        eventArtistId: true,
        eventId: true,
        event: {
          select: {
            id: true,
            name: true,
            startDate: true,
          },
        },
        stage: {
          select: {
            name: true,
          },
        },
        eventArtist: {
          select: {
            id: true,
            displayName: true,
            primaryDjId: true,
          },
        },
      },
      orderBy: [{ createdAt: 'desc' }],
    }),
  ]);

  return { artists, performances };
}

const normalizePagination = (value: number | undefined, fallback: number, max: number): number => {
  if (!Number.isFinite(value) || !value || value <= 0) {
    return fallback;
  }
  return Math.min(Math.floor(value), max);
};

const loadJobForResponse = (tx: Prisma.TransactionClient | PrismaClient, jobId: string) =>
  tx.dJEventBindingReviewJob.findUniqueOrThrow({
    where: { id: jobId },
    include: REVIEW_JOB_INCLUDE,
  });

const refreshJobStatus = async (tx: Prisma.TransactionClient, jobId: string) => {
  const job = await tx.dJEventBindingReviewJob.findUniqueOrThrow({
    where: { id: jobId },
    include: {
      candidates: {
        select: {
          status: true,
        },
      },
    },
  });

  const appliedCount = job.candidates.filter((candidate) => candidate.status === 'applied').length;
  const status = computeJobStatus({
    exactCount: job.exactCount,
    fuzzyCount: job.fuzzyCount,
    appliedCount,
    candidates: job.candidates,
  });

  return tx.dJEventBindingReviewJob.update({
    where: { id: jobId },
    data: {
      appliedCount,
      status,
      completedAt: status === 'applied' || status === 'dismissed' ? new Date() : null,
      updatedAt: new Date(),
    },
    include: REVIEW_JOB_INCLUDE,
  });
};

export async function createDJEventBindingReviewJobForDJ(
  djId: string,
  input: {
    triggerSource: DJEventBindingTriggerSource;
    createdById?: string | null;
  }
) {
  const dj = await prisma.dJ.findUnique({
    where: { id: djId },
    select: {
      id: true,
      name: true,
      aliases: true,
      nameI18n: true,
    },
  });
  if (!dj) {
    throw new Error('DJ not found');
  }

  const keys = buildDJLookupKeys(dj);
  const universe = await loadCandidateUniverse();
  const candidates: CandidateDraft[] = [];
  const seen = new Set<string>();

  for (const artist of universe.artists) {
    const artistMatch = classifyCandidate(artist.displayName, keys);
    if (artistMatch) {
      const candidate: CandidateDraft = {
        djId: dj.id,
        eventId: artist.eventId,
        eventArtistId: artist.id,
        eventArtistMemberId: null,
        eventPerformanceId: null,
        sourceType: 'lineup_artist',
        matchTier: artistMatch.tier,
        matchScore: artistMatch.score,
        matchReason: artistMatch.reason,
        rawName: artist.displayName,
        normalizedKey: normalizeDJBindingName(artist.displayName),
        compactKey: compactDJBindingName(artist.displayName),
        eventNameSnapshot: artist.event.name,
        stageNameSnapshot: null,
        startAtSnapshot: artist.event.startDate,
        needsSplit: /\b(b2b|b3b|vs|feat\.?|&|\/|,)\b/i.test(artist.displayName),
      };
      const dedupKey = buildCandidateDedupKey(candidate);
      if (!seen.has(dedupKey)) {
        seen.add(dedupKey);
        candidates.push(candidate);
      }
    }

    for (const member of artist.members) {
      const memberMatch = classifyCandidate(member.memberNameSnapshot, keys);
      if (!memberMatch) continue;
      const candidate: CandidateDraft = {
        djId: dj.id,
        eventId: artist.eventId,
        eventArtistId: artist.id,
        eventArtistMemberId: member.id,
        eventPerformanceId: null,
        sourceType: 'lineup_member',
        matchTier: memberMatch.tier,
        matchScore: memberMatch.score,
        matchReason: memberMatch.reason,
        rawName: member.memberNameSnapshot,
        normalizedKey: normalizeDJBindingName(member.memberNameSnapshot),
        compactKey: compactDJBindingName(member.memberNameSnapshot),
        eventNameSnapshot: artist.event.name,
        stageNameSnapshot: null,
        startAtSnapshot: artist.event.startDate,
        needsSplit: false,
      };
      const dedupKey = buildCandidateDedupKey(candidate);
      if (!seen.has(dedupKey)) {
        seen.add(dedupKey);
        candidates.push(candidate);
      }
    }
  }

  for (const performance of universe.performances) {
    const performanceName = String(performance.displayNameSnapshot || performance.eventArtist.displayName || '').trim();
    const slotMatch = classifyCandidate(performanceName, keys);
    if (!slotMatch) continue;
    const candidate: CandidateDraft = {
      djId: dj.id,
      eventId: performance.eventId,
      eventArtistId: performance.eventArtistId,
      eventArtistMemberId: null,
      eventPerformanceId: performance.id,
      sourceType: 'timetable_slot',
      matchTier: slotMatch.tier,
      matchScore: slotMatch.score,
      matchReason: slotMatch.reason,
      rawName: performanceName,
      normalizedKey: normalizeDJBindingName(performanceName),
      compactKey: compactDJBindingName(performanceName),
      eventNameSnapshot: performance.event.name,
      stageNameSnapshot: performance.stage?.name ?? null,
      startAtSnapshot: performance.startAt ?? performance.event.startDate,
      needsSplit: /\b(b2b|b3b|vs|feat\.?|&|\/|,)\b/i.test(performanceName),
    };
    const dedupKey = buildCandidateDedupKey(candidate);
    if (!seen.has(dedupKey)) {
      seen.add(dedupKey);
      candidates.push(candidate);
    }
  }

  const exactCount = candidates.filter((candidate) => candidate.matchTier === 'exact').length;
  const fuzzyCount = candidates.filter((candidate) => candidate.matchTier === 'fuzzy').length;

  return prisma.$transaction(async (tx) => {
    const job = await tx.dJEventBindingReviewJob.create({
      data: {
        djId: dj.id,
        djNameSnapshot: dj.name,
        triggerSource: input.triggerSource,
        status: exactCount + fuzzyCount > 0 ? 'pending' : 'dismissed',
        exactCount,
        fuzzyCount,
        appliedCount: 0,
        createdById: input.createdById ?? null,
        completedAt: exactCount + fuzzyCount > 0 ? null : new Date(),
      },
    });

    if (candidates.length) {
      await tx.dJEventBindingReviewCandidate.createMany({
        data: candidates.map((candidate) => ({
          jobId: job.id,
          djId: candidate.djId,
          eventId: candidate.eventId,
          eventArtistId: candidate.eventArtistId,
          eventArtistMemberId: candidate.eventArtistMemberId,
          eventPerformanceId: candidate.eventPerformanceId,
          sourceType: candidate.sourceType,
          matchTier: candidate.matchTier,
          matchScore: candidate.matchScore,
          matchReason: candidate.matchReason,
          rawName: candidate.rawName,
          normalizedKey: candidate.normalizedKey,
          compactKey: candidate.compactKey,
          eventNameSnapshot: candidate.eventNameSnapshot,
          stageNameSnapshot: candidate.stageNameSnapshot,
          startAtSnapshot: candidate.startAtSnapshot,
          needsSplit: candidate.needsSplit,
          status: 'pending',
        })),
      });
    }

    return loadJobForResponse(tx, job.id);
  });
}

export async function applyDJEventBindingReviewCandidates(
  jobId: string,
  candidateIds: string[],
  actorId: string
) {
  void actorId;
  const normalizedIds = Array.from(new Set(candidateIds.map((id) => String(id || '').trim()).filter(Boolean)));
  if (!normalizedIds.length) {
    throw new Error('candidateIds is required');
  }

  return prisma.$transaction(async (tx) => {
    const rows = await tx.dJEventBindingReviewCandidate.findMany({
      where: {
        jobId,
        id: { in: normalizedIds },
      },
      orderBy: { createdAt: 'asc' },
    });

    if (!rows.length) {
      throw new Error('No review candidates found');
    }

    for (const row of rows) {
      if (row.status !== 'pending') continue;

      if (row.eventArtistMemberId) {
        const member = await tx.eventArtistMember.findUnique({
          where: { id: row.eventArtistMemberId },
          select: { djId: true, eventArtistId: true },
        });
        if (!member || member.djId) {
          await tx.dJEventBindingReviewCandidate.update({
            where: { id: row.id },
            data: {
              status: 'skipped_already_bound',
            },
          });
          continue;
        }

        await tx.eventArtistMember.update({
          where: { id: row.eventArtistMemberId },
          data: { djId: row.djId },
        });

        const siblingCount = await tx.eventArtistMember.count({
          where: { eventArtistId: member.eventArtistId },
        });
        if (siblingCount === 1 && row.eventArtistId) {
          const artist = await tx.eventArtist.findUnique({
            where: { id: row.eventArtistId },
            select: { primaryDjId: true },
          });
          if (artist && !artist.primaryDjId) {
            await tx.eventArtist.update({
              where: { id: row.eventArtistId },
              data: { primaryDjId: row.djId },
            });
          }
        }
      } else if (row.eventArtistId) {
        const artist = await tx.eventArtist.findUnique({
          where: { id: row.eventArtistId },
          include: {
            members: {
              orderBy: { memberOrder: 'asc' },
            },
          },
        });
        if (!artist || artist.primaryDjId) {
          await tx.dJEventBindingReviewCandidate.update({
            where: { id: row.id },
            data: {
              status: 'skipped_already_bound',
            },
          });
          continue;
        }

        await tx.eventArtist.update({
          where: { id: row.eventArtistId },
          data: { primaryDjId: row.djId },
        });

        const firstUnboundMember = artist.members.find((member) => !member.djId);
        if (firstUnboundMember) {
          await tx.eventArtistMember.update({
            where: { id: firstUnboundMember.id },
            data: { djId: row.djId },
          });
        } else if (artist.members.length === 0) {
          await tx.eventArtistMember.create({
            data: {
              eventArtistId: row.eventArtistId,
              djId: row.djId,
              memberNameSnapshot: row.rawName,
              memberOrder: 0,
              role: 'performer',
            },
          });
        }
      } else {
        continue;
      }

      await tx.dJEventBindingReviewCandidate.update({
        where: { id: row.id },
        data: {
          status: 'applied',
          appliedAt: new Date(),
        },
      });
    }

    return refreshJobStatus(tx, jobId);
  });
}

export async function applyExactDJEventBindingReviewCandidates(jobId: string, actorId: string) {
  void actorId;
  const exactCandidates = await prisma.dJEventBindingReviewCandidate.findMany({
    where: {
      jobId,
      matchTier: 'exact',
      status: 'pending',
      needsSplit: false,
    },
    select: { id: true },
  });
  if (!exactCandidates.length) {
    return getDJEventBindingReviewJobDetail(jobId);
  }
  return applyDJEventBindingReviewCandidates(jobId, exactCandidates.map((item) => item.id), actorId);
}

export async function dismissDJEventBindingReviewCandidates(
  jobId: string,
  input: {
    candidateIds?: string[];
    dismissAll?: boolean;
  }
) {
  return prisma.$transaction(async (tx) => {
    const where: Prisma.DJEventBindingReviewCandidateWhereInput = {
      jobId,
      status: 'pending',
    };
    if (!input.dismissAll) {
      const candidateIds = Array.from(new Set((input.candidateIds ?? []).map((id) => String(id || '').trim()).filter(Boolean)));
      if (!candidateIds.length) {
        throw new Error('candidateIds is required');
      }
      where.id = { in: candidateIds };
    }

    await tx.dJEventBindingReviewCandidate.updateMany({
      where,
      data: {
        status: 'dismissed',
      },
    });

    return refreshJobStatus(tx, jobId);
  });
}

export async function listDJEventBindingReviewJobs(input: ListDJEventBindingReviewJobsInput = {}) {
  const page = normalizePagination(input.page, 1, 10000);
  const limit = normalizePagination(input.limit, 20, 100);
  const where: Prisma.DJEventBindingReviewJobWhereInput = {};
  const normalizedStatus = String(input.status || '').trim();
  if (normalizedStatus) {
    where.status = normalizedStatus;
  }

  const [total, items] = await Promise.all([
    prisma.dJEventBindingReviewJob.count({ where }),
    prisma.dJEventBindingReviewJob.findMany({
      where,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      skip: (page - 1) * limit,
      take: limit,
      include: {
        dj: {
          select: {
            id: true,
            name: true,
            avatarUrl: true,
          },
        },
      },
    }),
  ]);

  return {
    items,
    pagination: {
      page,
      limit,
      total,
      totalPages: Math.max(1, Math.ceil(total / limit)),
    },
  };
}

export async function getDJEventBindingReviewJobDetail(jobId: string) {
  return loadJobForResponse(prisma, jobId);
}

export const djEventBindingReviewService = {
  createJobForDJ: createDJEventBindingReviewJobForDJ,
  listJobs: listDJEventBindingReviewJobs,
  getJobDetail: getDJEventBindingReviewJobDetail,
  applyCandidates: applyDJEventBindingReviewCandidates,
  applyExactCandidates: applyExactDJEventBindingReviewCandidates,
  dismissCandidates: dismissDJEventBindingReviewCandidates,
};
