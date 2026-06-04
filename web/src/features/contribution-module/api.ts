import { authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';
import { getApiUrl } from '@/lib/config';
import type { ContributionEntityType, ContributionListResponse } from './types';

export const contributionModuleApi = {
  fetchEntityContributors(entityType: ContributionEntityType, entityId: string): Promise<ContributionListResponse> {
    const path = entityType === 'event' ? `/v1/events/${entityId}/contributors` : `/v1/djs/${entityId}/contributors`;
    return authenticatedJsonFetch<ContributionListResponse>(getApiUrl(path));
  },
};
