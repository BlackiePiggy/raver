import type { RemoteEvent } from '../../data/discoverRemoteSource';
import {
  fetchRemoteEventsPage,
  fetchRemoteRecommendedEvents,
} from '../../data/discoverRemoteSource';

export type RecommendEventsRepository = {
  fetchRecommendedEvents(limit: number, statuses?: string[]): Promise<RemoteEvent[]>;
  fetchUpcomingEvents(limit: number): Promise<RemoteEvent[]>;
  fetchLegacyCandidates(status: string, perPage: number): Promise<RemoteEvent[]>;
};

export function createLiveRecommendEventsRepository(): RecommendEventsRepository {
  return {
    fetchRecommendedEvents(limit, statuses) {
      return fetchRemoteRecommendedEvents(limit, statuses);
    },
    async fetchUpcomingEvents(limit) {
      const page = await fetchRemoteEventsPage({
        page: 1,
        limit,
        status: 'upcoming',
      });

      return page.items
        .filter(event => (event.status ?? '').toLowerCase() !== 'cancelled')
        .sort((left, right) => {
          if (left.startDate === right.startDate) {
            return left.endDate.localeCompare(right.endDate);
          }
          return left.startDate.localeCompare(right.startDate);
        });
    },
    async fetchLegacyCandidates(status, perPage) {
      const firstPage = await fetchRemoteEventsPage({
        page: 1,
        limit: perPage,
        status,
      });

      let merged = firstPage.items.slice();
      const totalPages = Math.max(firstPage.pagination?.totalPages ?? 1, 1);

      if (totalPages > 1) {
        const randomPage = Math.floor(Math.random() * totalPages) + 1;
        if (randomPage > 1) {
          const randomPageResult = await fetchRemoteEventsPage({
            page: randomPage,
            limit: perPage,
            status,
          });
          merged = merged.concat(randomPageResult.items);
        }
      }

      const uniqueByID = new Map<string, RemoteEvent>();
      for (const event of merged) {
        if ((event.status ?? '').toLowerCase() === 'cancelled') {
          continue;
        }
        uniqueByID.set(event.id, event);
      }

      return Array.from(uniqueByID.values());
    },
  };
}
