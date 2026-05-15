import { Prisma, PrismaClient } from '@prisma/client';
import { normalizeCountryBiTextPayload } from '../utils/country-i18n';
import { normalizeTriTextPayload } from '../utils/i18n';

const prisma = new PrismaClient();

const cozeDjEnrichmentRunUrl = String(
  process.env.COZE_DJ_ENRICH_RUN_URL || 'https://wd6gv5pg6k.coze.site/run'
).trim();
const cozeDjEnrichmentToken = String(
  process.env.COZE_DJ_ENRICH_TOKEN || process.env.COZE_WORKFLOW_TOKEN || ''
).trim();
const cozeDjEnrichmentTimeoutMs = (() => {
  const parsed = Number(process.env.COZE_DJ_ENRICH_TIMEOUT_MS || 120000);
  if (Number.isFinite(parsed) && parsed >= 10_000 && parsed <= 600_000) {
    return Math.floor(parsed);
  }
  return 120_000;
})();
const djEnrichmentWorkerIntervalMs = (() => {
  const parsed = Number(process.env.DJ_ENRICH_WORKER_INTERVAL_MS || 5000);
  if (Number.isFinite(parsed) && parsed >= 1000 && parsed <= 60000) {
    return Math.floor(parsed);
  }
  return 5000;
})();
const djEnrichmentDefaultConcurrency = (() => {
  const parsed = Number(process.env.DJ_ENRICH_MAX_CONCURRENCY || 10);
  if (Number.isFinite(parsed) && parsed >= 1 && parsed <= 20) {
    return Math.floor(parsed);
  }
  return 10;
})();

type DjEnrichmentInputItem = {
  djId?: string | null;
  name: string;
  bio?: string | null;
  country?: string | null;
  spotifyUrl?: string | null;
  source?: string | null;
};

type TriText = {
  zh: string;
  en: string;
  ja: string;
};

type LinkCandidate = {
  url: string | null;
  confidence?: number | null;
  source?: string | null;
};

type DjEnrichmentNormalized = {
  input: {
    name: string;
    bio: string | null;
    country: string | null;
    spotifyUrl: string | null;
    source: string | null;
  };
  resolution: {
    matchedName: string | null;
    isSamePersonConfident: boolean;
    samePersonConfidence: number;
    isElectronicDjConfident: boolean;
    electronicDjConfidence: number;
    shouldApplyGenres: boolean;
    reasoningShort: string;
  };
  texts: {
    bio: TriText | null;
    styles: Array<{
      canonical: string;
      zh: string;
      en: string;
      ja: string;
      confidence: number;
      source: string;
    }>;
    country: TriText | null;
    chineseAlias: string | null;
  };
  links: {
    officialWebsite: LinkCandidate | null;
    soundcloud: LinkCandidate | null;
    instagram: LinkCandidate | null;
    facebook: LinkCandidate | null;
    twitter: LinkCandidate | null;
    youtube: LinkCandidate | null;
    spotify: LinkCandidate | null;
    netease: LinkCandidate | null;
    qqMusic: LinkCandidate | null;
    wikipedia: LinkCandidate | null;
  };
  provenance: {
    genrePrimarySource: string;
    sourcesUsed: Array<{
      title?: string | null;
      url?: string | null;
      sourceType: string;
    }>;
  };
};

let workerStarted = false;
let workerTimer: NodeJS.Timeout | null = null;
let activeWorkerCount = 0;
let requestedConcurrency = djEnrichmentDefaultConcurrency;

const cleanText = (value: unknown): string => {
  if (typeof value !== 'string') return '';
  return value.trim();
};

const cleanNullableText = (value: unknown): string | null => {
  const text = cleanText(value);
  return text || null;
};

const cleanStringArray = (value: unknown, max = 50): string[] => {
  if (!Array.isArray(value)) return [];
  const out: string[] = [];
  const seen = new Set<string>();
  for (const entry of value) {
    const text = cleanText(entry);
    if (!text) continue;
    const key = text.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(text);
    if (out.length >= max) break;
  }
  return out;
};

const toNumberOrNull = (value: unknown): number | null => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
};

const asRecord = (value: unknown): Record<string, unknown> => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  return value as Record<string, unknown>;
};

const asTriText = (value: unknown): TriText | null => {
  const normalized = normalizeTriTextPayload(value, '');
  if (!normalized) return null;
  const zh = cleanText(normalized.zh);
  const en = cleanText(normalized.en);
  const ja = cleanText(normalized.ja);
  if (!zh && !en && !ja) return null;
  const fallback = zh || en || ja;
  return {
    zh: zh || fallback,
    en: en || fallback,
    ja: ja || fallback,
  };
};

const normalizeLinkCandidate = (value: unknown): LinkCandidate | null => {
  if (!value) return null;
  if (typeof value === 'string') {
    const url = cleanText(value);
    return url ? { url, confidence: null, source: null } : null;
  }
  const row = asRecord(value);
  const url = cleanNullableText(row.url ?? row.link);
  if (!url) return null;
  return {
    url,
    confidence: toNumberOrNull(row.confidence),
    source: cleanNullableText(row.source),
  };
};

const parsePossibleJson = (rawText: string): unknown => {
  const trimmed = String(rawText || '').trim();
  if (!trimmed) return null;
  try {
    return JSON.parse(trimmed);
  } catch (_error) {
    const firstBrace = trimmed.indexOf('{');
    const lastBrace = trimmed.lastIndexOf('}');
    if (firstBrace >= 0 && lastBrace > firstBrace) {
      const sliced = trimmed.slice(firstBrace, lastBrace + 1);
      try {
        return JSON.parse(sliced);
      } catch (_inner) {
        return null;
      }
    }
    return null;
  }
};

const buildCozeRequestPayload = (input: DjEnrichmentInputItem): Record<string, unknown> => {
  const payload: Record<string, unknown> = {
    name: input.name,
  };
  const bio = cleanNullableText(input.bio);
  const country = cleanNullableText(input.country);
  const spotifyUrl = cleanNullableText(input.spotifyUrl);
  const source = cleanNullableText(input.source);
  if (bio) payload.bio = bio;
  if (country) payload.country = country;
  if (spotifyUrl) payload.spotify_url = spotifyUrl;
  if (source) payload.source = source;
  return payload;
};

const runCozeDjEnrichment = async (input: DjEnrichmentInputItem): Promise<{ normalized: DjEnrichmentNormalized; raw: unknown }> => {
  if (!cozeDjEnrichmentRunUrl || !cozeDjEnrichmentToken) {
    throw new Error('COZE_DJ_ENRICH_RUN_URL or COZE_DJ_ENRICH_TOKEN is not configured');
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), cozeDjEnrichmentTimeoutMs);
  const payload = buildCozeRequestPayload(input);

  let rawText = '';
  try {
    const response = await fetch(cozeDjEnrichmentRunUrl, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${cozeDjEnrichmentToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });
    rawText = await response.text();
    if (!response.ok) {
      throw new Error(`Coze DJ enrichment request failed (${response.status}): ${rawText.slice(0, 500)}`);
    }
  } catch (error) {
    if (error instanceof Error && error.name === 'AbortError') {
      throw new Error(`COZE_DJ_ENRICH_TIMEOUT after ${cozeDjEnrichmentTimeoutMs}ms`);
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }

  const parsed = parsePossibleJson(rawText);
  if (!parsed) {
    throw new Error('Coze DJ enrichment returned non-JSON content');
  }
  const normalized = normalizeCozeDjEnrichment(parsed, input);
  return { normalized, raw: parsed };
};

const normalizeCozeDjEnrichment = (raw: unknown, input: DjEnrichmentInputItem): DjEnrichmentNormalized => {
  const outer = asRecord(raw);
  const root = asRecord(outer.result ?? raw);
  const resolution = asRecord(root.resolution);
  const texts = asRecord(root.texts);
  const links = asRecord(root.links);
  const provenance = asRecord(root.provenance);
  const rawStyles = Array.isArray(texts.styles) ? texts.styles : [];

  return {
    input: {
      name: input.name,
      bio: cleanNullableText(input.bio),
      country: cleanNullableText(input.country),
      spotifyUrl: cleanNullableText(input.spotifyUrl),
      source: cleanNullableText(input.source),
    },
    resolution: {
      matchedName: cleanNullableText(resolution.matchedName),
      isSamePersonConfident: Boolean(resolution.isSamePersonConfident),
      samePersonConfidence: toNumberOrNull(resolution.samePersonConfidence) ?? 0,
      isElectronicDjConfident: Boolean(resolution.isElectronicDjConfident),
      electronicDjConfidence: toNumberOrNull(resolution.electronicDjConfidence) ?? 0,
      shouldApplyGenres: Boolean(resolution.shouldApplyGenres),
      reasoningShort: cleanText(resolution.reasoningShort) || '',
    },
    texts: {
      bio: asTriText(texts.bio),
      styles: rawStyles
        .map((item) => {
          const row = asRecord(item);
          const canonical = cleanText(row.canonical || row.en || row.zh || row.ja);
          if (!canonical) return null;
          const tri = asTriText({
            zh: row.zh ?? canonical,
            en: row.en ?? canonical,
            ja: row.ja ?? canonical,
          });
          if (!tri) return null;
          return {
            canonical,
            zh: tri.zh,
            en: tri.en,
            ja: tri.ja,
            confidence: toNumberOrNull(row.confidence) ?? 0,
            source: cleanText(row.source) || 'unknown',
          };
        })
        .filter((item): item is DjEnrichmentNormalized['texts']['styles'][number] => Boolean(item)),
      country: asTriText(texts.country),
      chineseAlias: cleanNullableText(texts.chineseAlias),
    },
    links: {
      officialWebsite: normalizeLinkCandidate(links.officialWebsite),
      soundcloud: normalizeLinkCandidate(links.soundcloud),
      instagram: normalizeLinkCandidate(links.instagram),
      facebook: normalizeLinkCandidate(links.facebook),
      twitter: normalizeLinkCandidate(links.twitter),
      youtube: normalizeLinkCandidate(links.youtube),
      spotify: normalizeLinkCandidate(links.spotify),
      netease: normalizeLinkCandidate(links.netease),
      qqMusic: normalizeLinkCandidate(links.qqMusic),
      wikipedia: normalizeLinkCandidate(links.wikipedia),
    },
    provenance: {
      genrePrimarySource: cleanText(provenance.genrePrimarySource) || 'none',
      sourcesUsed: Array.isArray(provenance.sourcesUsed)
        ? provenance.sourcesUsed.reduce<DjEnrichmentNormalized['provenance']['sourcesUsed']>((acc, item) => {
            const row = asRecord(item);
            const sourceType = cleanText(row.sourceType);
            if (!sourceType) return acc;
            acc.push({
              title: cleanNullableText(row.title),
              url: cleanNullableText(row.url),
              sourceType,
            });
            return acc;
          }, [])
        : [],
    },
  };
};

const mergeUniqueCaseInsensitive = (base: string[], incoming: string[]): string[] => {
  const out: string[] = [];
  const seen = new Set<string>();
  for (const raw of [...base, ...incoming]) {
    const text = cleanText(raw);
    if (!text) continue;
    const key = text.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(text);
  }
  return out;
};

const buildSourceSameAs = (normalized: DjEnrichmentNormalized, existing: string[]): string[] => {
  const linkValues = [
    normalized.links.officialWebsite?.url,
    normalized.links.soundcloud?.url,
    normalized.links.instagram?.url,
    normalized.links.facebook?.url,
    normalized.links.twitter?.url,
    normalized.links.youtube?.url,
    normalized.links.spotify?.url,
    normalized.links.wikipedia?.url,
    ...normalized.provenance.sourcesUsed.map((item) => item.url || ''),
  ].map((item) => cleanText(item)).filter(Boolean);
  return mergeUniqueCaseInsensitive(existing, linkValues);
};

const splitDataSources = (value: string | null | undefined): string[] => {
  if (!value) return [];
  return value
    .split(/[|,;]+/)
    .map((item) => item.trim())
    .filter(Boolean);
};

const mergeDataSources = (
  existing: string | null | undefined,
  additions: Array<string | null | undefined>
): string | null => {
  const out = mergeUniqueCaseInsensitive(splitDataSources(existing), additions.map((item) => cleanText(item)));
  return out.length > 0 ? out.join('|') : null;
};

const buildDjApplyPatch = (
  dj: {
    name: string;
    aliases: string[];
    genres: string[];
    bio: string | null;
    bioI18n: Prisma.JsonValue | null;
    country: string | null;
    countryI18n: Prisma.JsonValue | null;
    spotifyUrl: string | null;
    website: string | null;
    soundcloudUrl: string | null;
    instagramUrl: string | null;
    facebookUrl: string | null;
    twitterUrl: string | null;
    youtubeUrl: string | null;
    neteaseUrl: string | null;
    qqMusicUrl: string | null;
    sourceWikipedia: string | null;
    sourceWebsite: string | null;
    sourceSameAs: string[];
    sourceDataSource: string | null;
  },
  normalized: DjEnrichmentNormalized
): Prisma.DJUpdateInput => {
  const patch: Prisma.DJUpdateInput = {};
  const nextAlias = cleanNullableText(normalized.texts.chineseAlias);
  if (nextAlias) {
    patch.aliases = mergeUniqueCaseInsensitive(dj.aliases ?? [], [nextAlias]);
  }

  const bioTri = asTriText(normalized.texts.bio);
  if (!dj.bio && bioTri?.en) {
    patch.bio = bioTri.en;
  }
  if (bioTri) {
    patch.bioI18n = bioTri as unknown as Prisma.InputJsonValue;
  }

  const countryTri = asTriText(normalized.texts.country);
  if (!dj.country && countryTri?.en) {
    patch.country = countryTri.en;
  }
  if (countryTri) {
    patch.countryI18n = normalizeCountryBiTextPayload(countryTri, countryTri.en || countryTri.zh || '') as unknown as Prisma.InputJsonValue;
  }

  const safeSetIfMissing = <K extends keyof Prisma.DJUpdateInput>(key: K, current: string | null, next: string | null) => {
    if (!current && next) {
      patch[key] = next as Prisma.DJUpdateInput[K];
    }
  };

  safeSetIfMissing('website', dj.website, cleanNullableText(normalized.links.officialWebsite?.url));
  safeSetIfMissing('spotifyUrl', dj.spotifyUrl, cleanNullableText(normalized.links.spotify?.url));
  safeSetIfMissing('soundcloudUrl', dj.soundcloudUrl, cleanNullableText(normalized.links.soundcloud?.url));
  safeSetIfMissing('instagramUrl', dj.instagramUrl, cleanNullableText(normalized.links.instagram?.url));
  safeSetIfMissing('facebookUrl', dj.facebookUrl, cleanNullableText(normalized.links.facebook?.url));
  safeSetIfMissing('twitterUrl', dj.twitterUrl, cleanNullableText(normalized.links.twitter?.url));
  safeSetIfMissing('youtubeUrl', dj.youtubeUrl, cleanNullableText(normalized.links.youtube?.url));
  safeSetIfMissing('neteaseUrl', dj.neteaseUrl, cleanNullableText(normalized.links.netease?.url));
  safeSetIfMissing('qqMusicUrl', dj.qqMusicUrl, cleanNullableText(normalized.links.qqMusic?.url));
  safeSetIfMissing('sourceWikipedia', dj.sourceWikipedia, cleanNullableText(normalized.links.wikipedia?.url));
  safeSetIfMissing('sourceWebsite', dj.sourceWebsite, cleanNullableText(normalized.links.officialWebsite?.url));

  patch.sourceSameAs = buildSourceSameAs(normalized, dj.sourceSameAs ?? []);
  patch.sourceDataSource = mergeDataSources(dj.sourceDataSource, ['coze_enrichment']);

  if (
    normalized.resolution.isSamePersonConfident &&
    normalized.resolution.isElectronicDjConfident &&
    normalized.resolution.shouldApplyGenres
  ) {
    const genreSource = cleanText(normalized.provenance.genrePrimarySource).toLowerCase();
    if (genreSource === 'wikipedia' || genreSource === 'official' || genreSource === 'spotify') {
      const nextGenres = cleanStringArray(normalized.texts.styles.map((item) => item.canonical));
      if (nextGenres.length > 0) {
        patch.genres = mergeUniqueCaseInsensitive(dj.genres ?? [], nextGenres);
      }
    }
  }

  return patch;
};

const updateJobCounters = async (jobId: string): Promise<void> => {
  const rows = await prisma.dJEnrichmentResult.findMany({
    where: { jobId },
    select: { status: true, applyStatus: true },
  });
  const summary = rows.reduce(
    (acc: { queued: number; running: number; success: number; failed: number; reviewed: number }, row) => {
      if (row.status === 'queued') acc.queued += 1;
      else if (row.status === 'running') acc.running += 1;
      else if (row.status === 'completed') acc.success += 1;
      else if (row.status === 'failed') acc.failed += 1;
      if (row.applyStatus !== 'pending_review') acc.reviewed += 1;
      return acc;
    },
    { queued: 0, running: 0, success: 0, failed: 0, reviewed: 0 }
  );
  const status =
    summary.running > 0
      ? 'running'
      : summary.queued > 0
        ? (summary.success > 0 || summary.failed > 0 ? 'partially_completed' : 'pending')
        : summary.failed > 0 && summary.success === 0
          ? 'failed'
          : 'completed';
  await prisma.dJEnrichmentJob.update({
    where: { id: jobId },
    data: {
      status,
      queuedCount: summary.queued,
      runningCount: summary.running,
      successCount: summary.success,
      failedCount: summary.failed,
      reviewedCount: summary.reviewed,
      startedAt: status === 'pending' ? undefined : new Date(),
      completedAt: summary.queued === 0 && summary.running === 0 ? new Date() : null,
    },
  });
};

export const createDjEnrichmentJob = async (
  requestedById: string,
  djIds: string[],
  options?: { maxConcurrency?: number | null }
): Promise<{ jobId: string; acceptedCount: number; maxConcurrency: number }> => {
  const dedupIds = mergeUniqueCaseInsensitive([], djIds);
  if (dedupIds.length === 0) {
    throw new Error('djIds cannot be empty');
  }
  const requested = Number(options?.maxConcurrency);
  if (Number.isFinite(requested)) {
    requestedConcurrency = Math.max(1, Math.min(20, Math.floor(requested)));
  }
  const djs = await prisma.dJ.findMany({
    where: { id: { in: dedupIds } },
    select: {
      id: true,
      name: true,
      bio: true,
      country: true,
      sourceWebsite: true,
      sourceWikipedia: true,
      sourceSameAs: true,
      website: true,
      spotifyUrl: true,
      spotifyId: true,
    },
  });
  if (djs.length === 0) {
    throw new Error('No matching DJs found');
  }

  const job = await prisma.dJEnrichmentJob.create({
    data: {
      requestedById,
      status: 'pending',
      applyMode: 'review_required',
      totalCount: djs.length,
      queuedCount: djs.length,
      results: {
        create: djs.map((dj) => {
          const spotifyUrl = dj.spotifyId ? `https://open.spotify.com/artist/${dj.spotifyId}` : null;
          const source = cleanNullableText(dj.sourceWikipedia || dj.sourceWebsite || dj.website || dj.sourceSameAs?.[0]);
          const inputPayload: DjEnrichmentInputItem = {
            djId: dj.id,
            name: dj.name,
            bio: dj.bio,
            country: dj.country,
            spotifyUrl,
            source,
          };
          return {
            djId: dj.id,
            inputName: dj.name,
            status: 'queued',
            applyStatus: 'pending_review',
            inputPayload: inputPayload as unknown as Prisma.InputJsonValue,
          };
        }),
      },
    },
  });
  return { jobId: job.id, acceptedCount: djs.length, maxConcurrency: requestedConcurrency };
};

const processSingleQueuedResult = async (resultId: string): Promise<void> => {
  const claimed = await prisma.dJEnrichmentResult.updateMany({
    where: { id: resultId, status: 'queued' },
    data: { status: 'running', errorMessage: null },
  });
  if (claimed.count === 0) return;

  const row = await prisma.dJEnrichmentResult.findUnique({
    where: { id: resultId },
    select: {
      id: true,
      jobId: true,
      inputPayload: true,
      inputName: true,
    },
  });
  if (!row) return;

  try {
    const input = asRecord(row.inputPayload) as unknown as DjEnrichmentInputItem;
    const normalizedInput: DjEnrichmentInputItem = {
      djId: cleanNullableText(input.djId),
      name: cleanText(input.name) || row.inputName,
      bio: cleanNullableText(input.bio),
      country: cleanNullableText(input.country),
      spotifyUrl: cleanNullableText(input.spotifyUrl),
      source: cleanNullableText(input.source),
    };
    const coze = await runCozeDjEnrichment(normalizedInput);
    await prisma.dJEnrichmentResult.update({
      where: { id: row.id },
      data: {
        status: 'completed',
        normalizedResult: coze.normalized as unknown as Prisma.InputJsonValue,
        cozeRawResponse: coze.raw as Prisma.InputJsonValue,
        matchConfidence: coze.normalized.resolution.samePersonConfidence,
        isMatchConfident: coze.normalized.resolution.isSamePersonConfident,
        electronicConfidence: coze.normalized.resolution.electronicDjConfidence,
        isElectronicDjConfident: coze.normalized.resolution.isElectronicDjConfident,
        genreConfidence:
          coze.normalized.texts.styles.length > 0
            ? Math.max(...coze.normalized.texts.styles.map((item) => item.confidence || 0))
            : null,
        shouldApplyGenres: coze.normalized.resolution.shouldApplyGenres,
      },
    });
  } catch (error) {
    await prisma.dJEnrichmentResult.update({
      where: { id: row.id },
      data: {
        status: 'failed',
        errorMessage: error instanceof Error ? error.message : String(error),
      },
    });
  } finally {
    await updateJobCounters(row.jobId);
  }
};

const fillWorkerSlots = async (): Promise<void> => {
  try {
    while (activeWorkerCount < requestedConcurrency) {
      const row = await prisma.dJEnrichmentResult.findFirst({
        where: { status: 'queued' },
        orderBy: [{ createdAt: 'asc' }],
        select: { id: true },
      });
      if (!row?.id) break;
      activeWorkerCount += 1;
      void processSingleQueuedResult(row.id)
        .catch((error) => {
          console.error('[dj-enrichment-worker] process failed:', error);
        })
        .finally(() => {
          activeWorkerCount = Math.max(0, activeWorkerCount - 1);
          void fillWorkerSlots();
        });
    }
  } catch (error) {
    console.error('[dj-enrichment-worker] fill slots failed:', error);
  }
};

const runWorkerTick = async (): Promise<void> => {
  await fillWorkerSlots();
};

export const startDjEnrichmentWorker = (): void => {
  if (workerStarted) return;
  workerStarted = true;
  workerTimer = setInterval(() => {
    void runWorkerTick();
  }, djEnrichmentWorkerIntervalMs);
  void runWorkerTick();
  console.info(
    `[dj-enrichment-worker] started intervalMs=${djEnrichmentWorkerIntervalMs} maxConcurrency=${requestedConcurrency}`
  );
};

export const stopDjEnrichmentWorker = (): void => {
  if (workerTimer) clearInterval(workerTimer);
  workerTimer = null;
  workerStarted = false;
};

export const listDjEnrichmentResults = async (input: {
  applyStatus?: string;
  reviewStatus?: string;
  limit?: number;
}) => {
  const where: Prisma.DJEnrichmentResultWhereInput = {};
  if (input.applyStatus) where.applyStatus = input.applyStatus;
  if (input.reviewStatus) where.status = input.reviewStatus;
  const items = await prisma.dJEnrichmentResult.findMany({
    where,
    include: {
      job: {
        select: {
          id: true,
          status: true,
          createdAt: true,
          requestedById: true,
        },
      },
      dj: {
        select: {
          id: true,
          name: true,
          aliases: true,
          genres: true,
          bio: true,
          bioI18n: true,
          country: true,
          countryI18n: true,
          spotifyUrl: true,
          website: true,
          soundcloudUrl: true,
          instagramUrl: true,
          facebookUrl: true,
          twitterUrl: true,
          youtubeUrl: true,
          neteaseUrl: true,
          qqMusicUrl: true,
          sourceWikipedia: true,
          sourceWebsite: true,
          sourceSameAs: true,
        },
      },
      reviewedBy: {
        select: { id: true, username: true, displayName: true, avatarUrl: true },
      },
    },
    orderBy: [{ createdAt: 'desc' }],
    take: input.limit ?? 200,
  });
  return items;
};

export const getDjEnrichmentResultDetail = async (id: string) => {
  return prisma.dJEnrichmentResult.findUnique({
    where: { id },
    include: {
      job: {
        include: {
          requestedBy: {
            select: { id: true, username: true, displayName: true, avatarUrl: true },
          },
        },
      },
      dj: true,
      reviewedBy: {
        select: { id: true, username: true, displayName: true, avatarUrl: true },
      },
    },
  });
};

export const reviewDjEnrichmentResult = async (input: {
  resultId: string;
  actorId: string;
  decision: 'approved' | 'rejected';
  reason?: string | null;
  reviewNotes?: Prisma.InputJsonObject | null;
}) => {
  const current = await prisma.dJEnrichmentResult.findUnique({
    where: { id: input.resultId },
    include: {
      dj: {
        select: {
          id: true,
          name: true,
          aliases: true,
          genres: true,
          bio: true,
          bioI18n: true,
          country: true,
          countryI18n: true,
          spotifyUrl: true,
          website: true,
          soundcloudUrl: true,
          instagramUrl: true,
          facebookUrl: true,
          twitterUrl: true,
          youtubeUrl: true,
          neteaseUrl: true,
          qqMusicUrl: true,
          sourceWikipedia: true,
          sourceWebsite: true,
          sourceSameAs: true,
          sourceDataSource: true,
        },
      },
    },
  });
  if (!current) throw new Error('DJ enrichment result not found');
  if (current.applyStatus !== 'pending_review') {
    throw new Error('DJ enrichment result has already been reviewed');
  }
  if (current.status !== 'completed') {
    throw new Error('DJ enrichment result is not ready for review');
  }

  const normalized = current.normalizedResult as unknown as DjEnrichmentNormalized | null;
  if (!normalized) {
    throw new Error('DJ enrichment normalized result is missing');
  }

  let applySummary: Prisma.InputJsonValue | undefined;
  let appliedAt: Date | null = null;

  if (input.decision === 'approved' && current.dj) {
    const patch = buildDjApplyPatch(current.dj, normalized);
    const updated = await prisma.dJ.update({
      where: { id: current.dj.id },
      data: patch,
      select: {
        id: true,
        name: true,
        aliases: true,
        genres: true,
        bio: true,
        country: true,
        spotifyUrl: true,
        website: true,
        soundcloudUrl: true,
        instagramUrl: true,
        facebookUrl: true,
        twitterUrl: true,
        youtubeUrl: true,
        neteaseUrl: true,
        qqMusicUrl: true,
        sourceWikipedia: true,
        sourceWebsite: true,
      },
    });
    applySummary = {
      decision: 'approved',
      appliedFields: Object.keys(patch),
      dj: updated,
    } as Prisma.InputJsonValue;
    appliedAt = new Date();
  } else {
    applySummary = {
      decision: input.decision,
      appliedFields: [],
    } as Prisma.InputJsonValue;
  }

  const nextApplyStatus = input.decision === 'approved' ? 'approved' : 'rejected';
  const updatedResult = await prisma.dJEnrichmentResult.update({
    where: { id: current.id },
    data: {
      applyStatus: nextApplyStatus,
      reviewReason: cleanNullableText(input.reason),
      reviewNotes: input.reviewNotes ?? undefined,
      reviewedAt: new Date(),
      reviewedById: input.actorId,
      appliedAt,
      applySummary,
    },
  });
  await updateJobCounters(current.jobId);
  return updatedResult;
};
