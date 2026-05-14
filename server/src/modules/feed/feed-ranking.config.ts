import crypto from 'crypto';

export type FeedExperimentBucket = 'control' | 'engagement_heavy' | 'freshness_heavy';

export type FeedRankingWeights = {
  freshnessBase: number;
  freshnessHalfLifeHours: number;
  likeWeight: number;
  commentWeight: number;
  repostWeight: number;
  saveWeight: number;
  shareWeight: number;
  recallFollowedAuthorWeight: number;
  recallFollowedDjWeight: number;
  recallBehaviorSimilarWeight: number;
  recallTrendingWeight: number;
  followedDjBonus: number;
  followingAuthorBonus: number;
  mutedAuthorPenalty: number;
  globalHidePenalty: number;
  seenTooOftenPenaltyFactor: number;
  seenTooOftenPenaltyMax: number;
  exposureLimit: number;
  exploreMinFreshness: number;
};

export const FEED_RANKING_WEIGHTS_VERSION = 'feed-rank-v2-ab';

const parseBool = (value: string | null | undefined, fallback: boolean): boolean => {
  if (!value) return fallback;
  const normalized = value.trim().toLowerCase();
  if (normalized === 'true' || normalized === '1' || normalized === 'yes') return true;
  if (normalized === 'false' || normalized === '0' || normalized === 'no') return false;
  return fallback;
};

const normalizePositiveInt = (
  value: string | undefined,
  fallback: number,
  min: number,
  max: number
): number => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  const rounded = Math.floor(parsed);
  if (!Number.isFinite(rounded)) return fallback;
  return Math.max(min, Math.min(max, rounded));
};

const feedExperimentBucketSet = new Set<FeedExperimentBucket>([
  'control',
  'engagement_heavy',
  'freshness_heavy',
]);

const FEED_AB_ENABLED = parseBool(process.env.FEED_AB_ENABLED, true);
const FEED_AB_CONTROL_PERCENT = normalizePositiveInt(process.env.FEED_AB_CONTROL_PERCENT, 40, 1, 100);
const FEED_AB_ENGAGEMENT_PERCENT = normalizePositiveInt(process.env.FEED_AB_ENGAGEMENT_PERCENT, 30, 0, 100);
const FEED_AB_FRESHNESS_PERCENT = Math.max(
  0,
  Math.min(100, 100 - FEED_AB_CONTROL_PERCENT - FEED_AB_ENGAGEMENT_PERCENT)
);

const FEED_RANKING_BASE_WEIGHTS: FeedRankingWeights = {
  freshnessBase: 80,
  freshnessHalfLifeHours: 20,
  likeWeight: 1,
  commentWeight: 1.8,
  repostWeight: 2.2,
  saveWeight: 2.4,
  shareWeight: 2,
  recallFollowedAuthorWeight: 24,
  recallFollowedDjWeight: 30,
  recallBehaviorSimilarWeight: 28,
  recallTrendingWeight: 6,
  followedDjBonus: 40,
  followingAuthorBonus: 35,
  mutedAuthorPenalty: 120,
  globalHidePenalty: 0.8,
  seenTooOftenPenaltyFactor: 0.5,
  seenTooOftenPenaltyMax: 8,
  exposureLimit: 2,
  exploreMinFreshness: 40,
};

export const buildFeedRankingWeights = (bucket: FeedExperimentBucket): FeedRankingWeights => {
  const base = FEED_RANKING_BASE_WEIGHTS;
  if (bucket === 'engagement_heavy') {
    return {
      ...base,
      freshnessBase: base.freshnessBase * 0.78,
      likeWeight: base.likeWeight * 1.35,
      commentWeight: base.commentWeight * 1.35,
      repostWeight: base.repostWeight * 1.3,
      saveWeight: base.saveWeight * 1.3,
      shareWeight: base.shareWeight * 1.3,
      recallBehaviorSimilarWeight: base.recallBehaviorSimilarWeight * 1.12,
    };
  }
  if (bucket === 'freshness_heavy') {
    return {
      ...base,
      freshnessBase: base.freshnessBase * 1.28,
      freshnessHalfLifeHours: base.freshnessHalfLifeHours * 0.8,
      likeWeight: base.likeWeight * 0.85,
      commentWeight: base.commentWeight * 0.88,
      repostWeight: base.repostWeight * 0.85,
      saveWeight: base.saveWeight * 0.88,
      shareWeight: base.shareWeight * 0.88,
      recallTrendingWeight: base.recallTrendingWeight * 1.4,
      exploreMinFreshness: 48,
    };
  }
  return base;
};

export const normalizeFeedExperimentBucket = (value: unknown): FeedExperimentBucket | null | 'invalid' => {
  if (value === null || value === undefined) return null;
  const normalized = String(value || '')
    .trim()
    .toLowerCase();
  if (!normalized) return null;
  return feedExperimentBucketSet.has(normalized as FeedExperimentBucket)
    ? (normalized as FeedExperimentBucket)
    : 'invalid';
};

const stableBucketPercentFromSeed = (seed: string): number => {
  const hash = crypto.createHash('sha256').update(seed).digest();
  const value = hash.readUInt32BE(0);
  return value % 100;
};

export const resolveFeedExperimentBucket = (
  overrideValue: unknown,
  viewerId: string | undefined
): FeedExperimentBucket => {
  const override = normalizeFeedExperimentBucket(overrideValue);
  if (override && override !== 'invalid') {
    return override;
  }

  if (!FEED_AB_ENABLED || !viewerId) {
    return 'control';
  }

  const bucketValue = stableBucketPercentFromSeed(`feed-ab:${viewerId}`);
  if (bucketValue < FEED_AB_CONTROL_PERCENT) return 'control';
  if (bucketValue < FEED_AB_CONTROL_PERCENT + FEED_AB_ENGAGEMENT_PERCENT) return 'engagement_heavy';
  if (bucketValue < FEED_AB_CONTROL_PERCENT + FEED_AB_ENGAGEMENT_PERCENT + FEED_AB_FRESHNESS_PERCENT) {
    return 'freshness_heavy';
  }
  return 'freshness_heavy';
};
