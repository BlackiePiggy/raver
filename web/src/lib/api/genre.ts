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

export type GenreSoundCueTrack = {
  title: string;
  artist: string;
  spotifyUrl: string | null;
  appleMusicUrl: string | null;
  neteaseUrl: string | null;
  soundcloudUrl: string | null;
  beatportUrl: string | null;
};

export interface GenreDetail {
  id: string;
  name: string;
  path: string;
  themeColor: string;
  description: string;
  example: string;
  origin: string;
  era: string;
  bpm: string;
  backgroundImageURL: string;
  spotifyTrackURL: string;
  wikipediaURL: string;
  keyArtists: string[];
  keyArtistBindings: GenreKeyArtistBinding[];
  soundCueTracks: GenreSoundCueTrack[];
}

export interface GenreTreeSummaryNode {
  id: string;
  name: string;
  path: string;
  themeColor: string;
  children: GenreTreeSummaryNode[];
}

export type GenreTagLookupMap = Map<string, string>;

function normalizeGenreLookupKey(name: string): string {
  return name
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function buildGenreTagLookup(nodes: GenreTreeSummaryNode[]): GenreTagLookupMap {
  const map: GenreTagLookupMap = new Map();

  const visit = (node: GenreTreeSummaryNode) => {
    const key = normalizeGenreLookupKey(node.name);
    if (key && !map.has(key)) {
      map.set(key, node.id);
    }
    node.children.forEach(visit);
  };

  nodes.forEach(visit);
  return map;
}

class GenreAPI {
  async getGenre(id: string): Promise<GenreDetail> {
    const response = await fetch(`/v1/learn/genres/${encodeURIComponent(id)}`);

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Failed to fetch genre');
    }

    const result = await response.json();
    return result.data;
  }

  async getTreeSummary(): Promise<GenreTreeSummaryNode[]> {
    const response = await fetch('/v1/learn/genres/tree-summary');

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Failed to fetch genre tree summary');
    }

    const result = await response.json();
    return result.data;
  }

  async getTagLookup(): Promise<GenreTagLookupMap> {
    const nodes = await this.getTreeSummary();
    return buildGenreTagLookup(nodes);
  }
}

export { normalizeGenreLookupKey };
export const genreAPI = new GenreAPI();
