import { authenticatedJsonFetch } from '@/lib/auth/authenticated-fetch';
import { getApiUrl } from '@/lib/config';

export type GenreKeyArtistBinding = {
  name: string;
  djId: string | null;
  dj: {
    id: string;
    name: string;
    avatarUrl: string | null;
    avatarMediumUrl: string | null;
  } | null;
};

export type GenreAdminNode = {
  id: string;
  name: string;
  slug?: string;
  path: string;
  description: string;
  descriptionI18n: Record<string, string> | null;
  example: string;
  exampleI18n: Record<string, string> | null;
  spotifyTrackURL: string;
  wikipediaURL: string;
  keyArtists: string[];
  keyArtistBindings: GenreKeyArtistBinding[];
  parentId?: string | null;
  sortOrder?: number;
  children?: GenreAdminNode[];
};

type Envelope<T> = {
  data: T;
};

const buildGenreTree = (items: GenreAdminNode[]): GenreAdminNode[] => {
  const map = new Map<string, GenreAdminNode>();
  for (const item of items) {
    map.set(item.id, { ...item, children: [] });
  }
  const roots: GenreAdminNode[] = [];
  for (const item of items) {
    const current = map.get(item.id)!;
    if (item.parentId && map.has(item.parentId)) {
      map.get(item.parentId)!.children!.push(current);
    } else {
      roots.push(current);
    }
  }
  return roots;
};

export const genreAdminApi = {
  async fetchTree(): Promise<{ items: GenreAdminNode[] }> {
    const payload = await authenticatedJsonFetch<Envelope<{ items: GenreAdminNode[] }>>(getApiUrl('/v1/learn/genres/admin/tree'));
    return {
      items: buildGenreTree(payload.data.items),
    };
  },

  async updateContent(
    id: string,
    input: {
      description?: string | null;
      descriptionI18n?: Record<string, string> | null;
      example?: string | null;
      exampleI18n?: Record<string, string> | null;
    }
  ): Promise<GenreAdminNode> {
    const payload = await authenticatedJsonFetch<Envelope<GenreAdminNode>>(getApiUrl(`/v1/learn/genres/${encodeURIComponent(id)}/content`), {
      method: 'POST',
      body: JSON.stringify(input),
    });
    return payload.data;
  },

  async updateKeyArtists(
    id: string,
    input: {
      keyArtists?: string[];
      bindings?: Array<{ name: string; djId?: string | null }>;
    }
  ): Promise<GenreAdminNode> {
    const payload = await authenticatedJsonFetch<Envelope<GenreAdminNode>>(
      getApiUrl(`/v1/learn/genres/${encodeURIComponent(id)}/key-artist-bindings`),
      {
        method: 'POST',
        body: JSON.stringify(input),
      }
    );
    return payload.data;
  },

  async autoMatchKeyArtists(): Promise<{ matched: number; totalArtists: number; updatedGenres: number }> {
    const payload = await authenticatedJsonFetch<
      Envelope<{ matched: number; totalArtists: number; updatedGenres: number }>
    >(getApiUrl('/v1/learn/genres/key-artists/auto-match'), {
      method: 'POST',
    });
    return payload.data;
  },

  async createNode(input: {
    name: string;
    parentId?: string | null;
    slug?: string | null;
    sortOrder?: number | null;
  }): Promise<GenreAdminNode> {
    const payload = await authenticatedJsonFetch<Envelope<GenreAdminNode>>(getApiUrl('/v1/learn/genres/admin/nodes'), {
      method: 'POST',
      body: JSON.stringify(input),
    });
    return payload.data;
  },

  async updateNode(
    id: string,
    input: {
      name?: string;
      parentId?: string | null;
      slug?: string | null;
      sortOrder?: number | null;
    }
  ): Promise<GenreAdminNode> {
    const payload = await authenticatedJsonFetch<Envelope<GenreAdminNode>>(
      getApiUrl(`/v1/learn/genres/admin/nodes/${encodeURIComponent(id)}`),
      {
        method: 'PATCH',
        body: JSON.stringify(input),
      }
    );
    return payload.data;
  },

  async deleteNode(id: string): Promise<void> {
    await authenticatedJsonFetch<Envelope<{ success: true }>>(getApiUrl(`/v1/learn/genres/admin/nodes/${encodeURIComponent(id)}`), {
      method: 'DELETE',
    });
  },
};
