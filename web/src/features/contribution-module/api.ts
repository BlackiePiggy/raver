import { authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';
import { getApiUrl } from '@/lib/config';
import type { ContributionEntityType, ContributionListResponse } from './types';

type BffEnvelope<T> = {
  data?: T;
};

export const contributionModuleApi = {
  async fetchEntityContributors(entityType: ContributionEntityType, entityId: string): Promise<ContributionListResponse> {
    const path = entityType === 'event' ? `/v1/events/${entityId}/contributors` : `/v1/djs/${entityId}/contributors`;
    const response = await authenticatedJsonFetch<BffEnvelope<ContributionListResponse>>(getApiUrl(path));
    return response.data ?? { items: [], summary: { totalCount: 0, creator: null, previewUsers: [], displayName: null } };
  },
};
