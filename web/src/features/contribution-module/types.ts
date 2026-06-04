export type ContributionEntityType = 'event' | 'dj';

export type ContributionUserLite = {
  id: string;
  username?: string | null;
  displayName?: string | null;
  avatarUrl?: string | null;
};

export type ContributionSummary = {
  totalCount: number;
  creator: ContributionUserLite | null;
  previewUsers: ContributionUserLite[];
  displayName: string | null;
};

export type ContributionListItem = {
  user: ContributionUserLite;
  role: 'creator' | 'editor';
  firstContributedAt: string;
  lastContributedAt: string;
  contributionCount: number;
  firstSubmissionId?: string | null;
  lastSubmissionId?: string | null;
  lastContributionSource?: string | null;
  createdAt: string;
  updatedAt: string;
};

export type ContributionListResponse = {
  items: ContributionListItem[];
  summary: ContributionSummary;
};
