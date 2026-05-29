import { NativeModules } from 'react-native';

type RemoteEnvelope<T> = {
  data: T;
};

type RemotePaginated<T> = {
  items: T[];
  pagination?: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
};

export type RemoteEventsPage = RemotePaginated<RemoteEvent>;

export type FetchRemoteEventsPageParams = {
  page?: number;
  limit?: number;
  search?: string;
  eventType?: string;
  status?: string;
  wikiFestivalId?: string;
};

export type RemoteEvent = {
  id: string;
  name: string;
  description?: string | null;
  eventType?: string | null;
  status?: string | null;
  city?: string | null;
  country?: string | null;
  coverImageUrl?: string | null;
  cardImageUrl?: string | null;
  lineupImageUrl?: string | null;
  venueName?: string | null;
  organizerName?: string | null;
  startDate: string;
  endDate: string;
  lineUpArtistCount?: number;
  lineupArtistCount?: number;
  timetableSlotCount?: number;
  manualLocation?: {
    formattedAddressI18n?: {
      zh?: string;
      en?: string;
      ja?: string;
    } | null;
    detailAddressI18n?: {
      zh?: string;
      en?: string;
      ja?: string;
    } | null;
  } | null;
  schedule?: {
    timeZone?: string | null;
    mode?: string | null;
    dayRolloverHour?: number | null;
  } | null;
  ticketTiers?: Array<{
    id?: string;
    name: string;
    price: number;
    currency?: string | null;
  }> | null;
  stageOrder?: string[] | null;
  lineupSlots?: Array<{
    id?: string;
    djName: string;
    stageName?: string | null;
    startTime: string;
    endTime: string;
    dj?: {
      id?: string;
      name?: string;
      country?: string | null;
    } | null;
  }> | null;
};

export type RemoteDJ = {
  id: string;
  name: string;
  genres?: string[] | null;
  avatarUrl?: string | null;
  country?: string | null;
  countryI18n?: {
    zh?: string;
    en?: string;
    ja?: string;
    enFull?: string;
  } | null;
  bio?: string | null;
  followerCount?: number | null;
  eventCount?: number | null;
  upcomingShows?: number | null;
  setCount?: number | null;
  honors?: Array<{
    id: string;
    rank?: number | null;
    year?: number | null;
    title?: string | null;
    subtitle?: string | null;
  }> | null;
};

export type RemoteFestival = {
  id: string;
  name: string;
  country?: string | null;
  city?: string | null;
  foundedYear?: string | null;
  frequency?: string | null;
  introduction?: string | null;
  avatarUrl?: string | null;
  backgroundUrl?: string | null;
  links?: Array<{
    title?: string | null;
    url?: string | null;
  }> | null;
};

export type RemoteLabel = {
  id: string;
  name: string;
  nation?: string | null;
  locationPeriod?: string | null;
  latestReleaseListing?: string | null;
  introduction?: string | null;
  genres?: string[] | null;
  genresPreview?: string | null;
  avatarUrl?: string | null;
  backgroundUrl?: string | null;
  soundcloudFollowers?: number | null;
  likes?: number | null;
};

export type RemoteRankingBoard = {
  id: string;
  title: string;
  subtitle?: string | null;
  description?: string | null;
  coverImageUrl?: string | null;
  years?: number[] | null;
  entityType?: string | null;
};

export type RemoteRankingBoardDetail = {
  boardId: string;
  title: string;
  subtitle?: string | null;
  description?: string | null;
  coverImageUrl?: string | null;
  entityType?: string | null;
  years?: number[] | null;
  year?: number | null;
  entries: Array<{
    rank: number;
    name: string;
    entityId?: string | null;
    delta?: number | null;
    dj?: {
      id: string;
      name: string;
      avatarUrl?: string | null;
      followerCount?: number | null;
      country?: string | null;
    } | null;
    festival?: {
      id: string;
      name: string;
      avatarUrl?: string | null;
      backgroundUrl?: string | null;
      country?: string | null;
      city?: string | null;
      tagline?: string | null;
    } | null;
  }>;
};

export type RemoteGenreSummaryNode = {
  id: string;
  name: string;
  path: string;
  children?: RemoteGenreSummaryNode[];
};

export type RemoteGenreDetail = {
  id: string;
  name: string;
  path: string;
  description?: string | null;
  descriptionI18n?: {
    zh?: string;
    en?: string;
    ja?: string;
  } | null;
};

export type RemoteEventsBootstrap = {
  ongoing: RemotePaginated<RemoteEvent>;
  upcoming: RemotePaginated<RemoteEvent>;
};

function resolveNativeBaseURL() {
  const scriptURL = (
    NativeModules as {
      SourceCode?: {
        scriptURL?: string;
      };
    }
  ).SourceCode?.scriptURL;

  if (!scriptURL) {
    return null;
  }

  const normalizedURL = scriptURL
    .replace(/^exp:\/\//, 'http://')
    .replace(/^exps:\/\//, 'https://');

  try {
    const url = new URL(normalizedURL);
    if (!url.hostname) {
      return null;
    }
    return `${url.protocol}//${url.hostname}:3901`;
  } catch {
    return null;
  }
}

function resolveBaseURL() {
  const envBaseURL = (
    globalThis as {
      process?: { env?: Record<string, string | undefined> };
    }
  ).process?.env?.EXPO_PUBLIC_RAVER_API_BASE_URL;

  if (envBaseURL && envBaseURL.trim().length > 0) {
    return envBaseURL.replace(/\/$/, '');
  }

  const location = (
    globalThis as {
      location?: { protocol?: string; hostname?: string };
    }
  ).location;

  if (location?.hostname) {
    const protocol = location.protocol || 'http:';
    return `${protocol}//${location.hostname}:3901`;
  }

  const nativeBaseURL = resolveNativeBaseURL();
  if (nativeBaseURL) {
    return nativeBaseURL;
  }

  return 'http://127.0.0.1:3901';
}

async function requestRemoteJSON<T>(path: string) {
  const requestURL = `${resolveBaseURL()}${path}`;
  console.log('discover remote request', requestURL);
  const response = await fetch(requestURL);
  console.log('discover remote response', response.status, requestURL);

  if (!response.ok) {
    throw new Error(`Remote request failed: ${response.status} ${path}`);
  }

  return (await response.json()) as T;
}

export async function fetchRemoteEventsBootstrap(limit = 6) {
  const payload = await requestRemoteJSON<RemoteEnvelope<RemoteEventsBootstrap>>(
    `/v1/events/bootstrap?limit=${limit}`,
  );
  return payload.data;
}

export async function fetchRemoteEventsPage({
  page = 1,
  limit = 10,
  search,
  eventType,
  status,
  wikiFestivalId,
}: FetchRemoteEventsPageParams = {}) {
  const query = new URLSearchParams({
    page: String(Math.max(1, page)),
    limit: String(Math.max(1, Math.min(100, limit))),
  });

  if (search?.trim()) {
    query.set('search', search.trim());
  }
  if (eventType?.trim()) {
    query.set('eventType', eventType.trim());
  }
  if (status?.trim()) {
    query.set('status', status.trim());
  }
  if (wikiFestivalId?.trim()) {
    query.set('wikiFestivalId', wikiFestivalId.trim());
  }

  const payload = await requestRemoteJSON<
    RemoteEnvelope<RemotePaginated<RemoteEvent>>
  >(`/v1/events?${query.toString()}`);
  return payload.data;
}

export async function fetchRemoteRecommendedEvents(
  limit = 6,
  statuses: string[] = ['ongoing', 'upcoming', 'ended'],
) {
  const normalizedStatuses = statuses
    .map(item => item.trim().toLowerCase())
    .filter(Boolean);
  const query = new URLSearchParams({
    limit: String(Math.max(1, Math.min(20, limit))),
  });

  if (normalizedStatuses.length > 0) {
    query.set('statuses', normalizedStatuses.join(','));
  }

  const payload = await requestRemoteJSON<
    RemoteEnvelope<RemotePaginated<RemoteEvent>>
  >(`/v1/events/recommendations?${query.toString()}`);
  return payload.data.items;
}

export async function fetchRemoteEventDetail(eventID: string) {
  const payload = await requestRemoteJSON<RemoteEnvelope<RemoteEvent>>(
    `/v1/events/${encodeURIComponent(eventID)}`,
  );
  return payload.data;
}

export async function fetchRemoteDJs(limit = 6) {
  const payload = await requestRemoteJSON<
    RemoteEnvelope<RemotePaginated<RemoteDJ>>
  >(`/v1/djs?page=1&limit=${limit}&sortBy=followerCount`);
  return payload.data.items;
}

export async function fetchRemoteDJDetail(djID: string) {
  const payload = await requestRemoteJSON<RemoteEnvelope<RemoteDJ>>(
    `/v1/djs/${encodeURIComponent(djID)}`,
  );
  return payload.data;
}

export async function fetchRemoteDJEvents(djID: string, limit = 6) {
  const payload = await requestRemoteJSON<
    RemoteEnvelope<RemotePaginated<RemoteEvent>>
  >(`/v1/djs/${encodeURIComponent(djID)}/events?page=1&limit=${limit}`);
  return payload.data.items;
}

export async function fetchRemoteFestivals(limit = 6) {
  const payload = await requestRemoteJSON<
    RemoteEnvelope<RemotePaginated<RemoteFestival>>
  >(`/v1/learn/festivals?page=1&limit=${limit}`);
  return payload.data.items;
}

export async function fetchRemoteFestivalDetail(festivalID: string) {
  const payload = await requestRemoteJSON<RemoteEnvelope<RemoteFestival>>(
    `/v1/learn/festivals/${encodeURIComponent(festivalID)}`,
  );
  return payload.data;
}

export async function fetchRemoteLabelList(limit = 6) {
  const payload = await requestRemoteJSON<
    RemoteEnvelope<RemotePaginated<RemoteLabel>>
  >(`/v1/learn/labels?page=1&limit=${limit}`);
  return payload.data.items;
}

export async function fetchRemoteLabelDetail(labelID: string) {
  const payload = await requestRemoteJSON<RemoteEnvelope<RemoteLabel>>(
    `/v1/learn/labels/${encodeURIComponent(labelID)}`,
  );
  return payload.data;
}

export async function fetchRemoteRankingBoards() {
  const payload = await requestRemoteJSON<RemoteEnvelope<RemoteRankingBoard[]>>(
    '/v1/learn/rankings',
  );
  return payload.data;
}

export async function fetchRemoteRankingBoardDetail(boardID: string, year?: number) {
  const suffix = typeof year === 'number' ? `?year=${year}` : '';
  const payload = await requestRemoteJSON<RemoteEnvelope<RemoteRankingBoardDetail>>(
    `/v1/learn/rankings/${encodeURIComponent(boardID)}${suffix}`,
  );
  return payload.data;
}

export async function fetchRemoteGenreTreeSummary() {
  const payload = await requestRemoteJSON<
    RemoteEnvelope<RemoteGenreSummaryNode[]>
  >('/v1/learn/genres/tree-summary');
  return payload.data;
}

export async function fetchRemoteGenreDetail(genreID: string) {
  const payload = await requestRemoteJSON<RemoteEnvelope<RemoteGenreDetail>>(
    `/v1/learn/genres/${encodeURIComponent(genreID)}`,
  );
  return payload.data;
}
