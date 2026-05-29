import { useCallback, useMemo, useState } from 'react';

import type { RemoteEvent } from '../../data/discoverRemoteSource';
import type { RecommendEventsRepository } from '../data/recommendEventsRepository';

type LoadPhase = 'idle' | 'initialLoading' | 'success' | 'empty' | 'failure';

type RecommendCache = {
  dateKey: string;
  userKey: string;
  events: RemoteEvent[];
};

type UseRecommendEventsViewModelOptions = {
  recommendationRepository: RecommendEventsRepository;
  sessionUserID?: string | null;
};

type UseRecommendEventsViewModelResult = {
  events: RemoteEvent[];
  phase: LoadPhase;
  isLoading: boolean;
  errorMessage: string | null;
  loadIfNeeded: () => Promise<void>;
  reload: () => Promise<void>;
};

const RECOMMENDATION_STATUSES = ['ongoing', 'upcoming', 'ended'];
const RECOMMENDATION_LIMIT = 10;
const LEGACY_PER_PAGE = 40;

let cachedDailyRecommendations: RecommendCache | null = null;

function todayKey(now = new Date()) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Shanghai',
  }).format(now);
}

function userCacheKey(sessionUserID?: string | null) {
  const trimmed = sessionUserID?.trim() ?? '';
  return trimmed.length > 0 ? trimmed : 'anonymous';
}

export function useRecommendEventsViewModel({
  recommendationRepository,
  sessionUserID,
}: UseRecommendEventsViewModelOptions): UseRecommendEventsViewModelResult {
  const [events, setEvents] = useState<RemoteEvent[]>([]);
  const [phase, setPhase] = useState<LoadPhase>('idle');
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [hasLoadedRecommendations, setHasLoadedRecommendations] = useState(false);

  const cacheKey = useMemo(() => userCacheKey(sessionUserID), [sessionUserID]);

  const applyCachedRecommendationsIfAvailable = useCallback(() => {
    if (events.length > 0) {
      return false;
    }
    if (
      cachedDailyRecommendations &&
      cachedDailyRecommendations.dateKey === todayKey() &&
      cachedDailyRecommendations.userKey === cacheKey &&
      cachedDailyRecommendations.events.length > 0
    ) {
      setEvents(cachedDailyRecommendations.events);
      setPhase('success');
      setHasLoadedRecommendations(true);
      return true;
    }
    return false;
  }, [cacheKey, events.length]);

  const cacheRecommendations = useCallback(
    (nextEvents: RemoteEvent[]) => {
      if (nextEvents.length === 0) {
        return;
      }
      cachedDailyRecommendations = {
        dateKey: todayKey(),
        userKey: cacheKey,
        events: nextEvents,
      };
    },
    [cacheKey],
  );

  const loadGuestDefaultRecommendations = useCallback(async () => {
    return recommendationRepository.fetchUpcomingEvents(RECOMMENDATION_LIMIT);
  }, [recommendationRepository]);

  const loadRecommendationsLegacy = useCallback(async () => {
    const buckets = await Promise.all(
      RECOMMENDATION_STATUSES.map(status =>
        recommendationRepository.fetchLegacyCandidates(status, LEGACY_PER_PAGE),
      ),
    );

    const candidatesByStatus = new Map<string, RemoteEvent[]>();
    RECOMMENDATION_STATUSES.forEach((status, index) => {
      candidatesByStatus.set(status, buckets[index] ?? []);
    });

    const selected: RemoteEvent[] = [];
    const selectedIDs = new Set<string>();

    for (const status of RECOMMENDATION_STATUSES) {
      const bucket = candidatesByStatus.get(status) ?? [];
      if (bucket.length === 0) {
        continue;
      }
      const shuffled = bucket.slice().sort(() => Math.random() - 0.5);
      const picked = shuffled.find(event => !selectedIDs.has(event.id));
      if (!picked) {
        continue;
      }
      selected.push(picked);
      selectedIDs.add(picked.id);
      if (selected.length >= RECOMMENDATION_LIMIT) {
        return selected;
      }
    }

    const pool = RECOMMENDATION_STATUSES.flatMap(
      status => candidatesByStatus.get(status) ?? [],
    ).sort(() => Math.random() - 0.5);

    for (const event of pool) {
      if (selectedIDs.has(event.id)) {
        continue;
      }
      selected.push(event);
      selectedIDs.add(event.id);
      if (selected.length >= RECOMMENDATION_LIMIT) {
        break;
      }
    }

    return selected;
  }, [recommendationRepository]);

  const loadRecommendations = useCallback(
    async (force: boolean) => {
      if (isLoading) {
        return;
      }
      if (!force && hasLoadedRecommendations && events.length > 0) {
        return;
      }

      applyCachedRecommendationsIfAvailable();
      const hadContent = events.length > 0;
      setIsLoading(true);
      setErrorMessage(null);
      if (!hadContent) {
        setPhase('initialLoading');
      }

      try {
        if (!sessionUserID) {
          const guestEvents = await loadGuestDefaultRecommendations();
          setEvents(guestEvents);
          cacheRecommendations(guestEvents);
          setHasLoadedRecommendations(true);
          setPhase(guestEvents.length > 0 ? 'success' : 'empty');
          return;
        }

        const recommended = await recommendationRepository.fetchRecommendedEvents(
          RECOMMENDATION_LIMIT,
          RECOMMENDATION_STATUSES,
        );

        if (recommended.length > 0) {
          setEvents(recommended);
          cacheRecommendations(recommended);
          setHasLoadedRecommendations(true);
          setPhase('success');
          return;
        }

        const legacyEvents = await loadRecommendationsLegacy();
        setEvents(legacyEvents);
        cacheRecommendations(legacyEvents);
        setHasLoadedRecommendations(true);
        setPhase(legacyEvents.length > 0 ? 'success' : 'empty');
      } catch (error) {
        try {
          const legacyEvents = await loadRecommendationsLegacy();
          setEvents(legacyEvents);
          cacheRecommendations(legacyEvents);
          setHasLoadedRecommendations(true);
          setPhase(legacyEvents.length > 0 ? 'success' : 'empty');
        } catch {
          const message =
            error instanceof Error
              ? error.message
              : 'Failed to load recommended events.';
          setErrorMessage(message);
          setPhase(hadContent ? 'success' : 'failure');
        }
      } finally {
        setIsLoading(false);
      }
    },
    [
      applyCachedRecommendationsIfAvailable,
      cacheRecommendations,
      events.length,
      hasLoadedRecommendations,
      isLoading,
      loadGuestDefaultRecommendations,
      loadRecommendationsLegacy,
      recommendationRepository,
      sessionUserID,
    ],
  );

  const loadIfNeeded = useCallback(async () => {
    applyCachedRecommendationsIfAvailable();
    if (hasLoadedRecommendations) {
      return;
    }
    await loadRecommendations(false);
  }, [applyCachedRecommendationsIfAvailable, hasLoadedRecommendations, loadRecommendations]);

  const reload = useCallback(async () => {
    await loadRecommendations(true);
  }, [loadRecommendations]);

  return {
    events,
    phase,
    isLoading,
    errorMessage,
    loadIfNeeded,
    reload,
  };
}
