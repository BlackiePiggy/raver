export interface GenreNode {
  id: string;
  name: string;
  description: string;
  children?: GenreNode[];
}

export const GENRE_TREE: GenreNode[] = [
  {
    id: 'house',
    name: 'House',
    description: '以四拍地板鼓点为核心，强调律动和舞池氛围。',
    children: [
      {
        id: 'deep-house',
        name: 'Deep House',
        description: '更柔和、更氛围化，低频和和声更细腻。',
      },
      {
        id: 'tech-house',
        name: 'Tech House',
        description: '融合 Techno 的极简与 House 的律动感。',
      },
      {
        id: 'progressive-house',
        name: 'Progressive House',
        description: '注重层层推进和情绪堆叠，适合大舞台。',
      },
    ],
  },
  {
    id: 'techno',
    name: 'Techno',
    description: '强调工业感、重复性和催眠式推进。',
    children: [
      {
        id: 'melodic-techno',
        name: 'Melodic Techno',
        description: '在 Techno 框架中加入旋律与情绪线。',
      },
      {
        id: 'hard-techno',
        name: 'Hard Techno',
        description: '速度更快、冲击更强、能量密度更高。',
      },
    ],
  },
  {
    id: 'bass-music',
    name: 'Bass Music',
    description: '强调低频冲击和节奏变化，现场表现力强。',
    children: [
      {
        id: 'dubstep',
        name: 'Dubstep',
        description: '以重低音和 Drop 变化为标志。',
      },
      {
        id: 'future-bass',
        name: 'Future Bass',
        description: '旋律化和弦与爆发式低频结合。',
      },
      {
        id: 'drum-and-bass',
        name: 'Drum & Bass',
        description: '高速 breakbeat 与深厚低频的经典组合。',
      },
    ],
  },
  {
    id: 'trance',
    name: 'Trance',
    description: '强调旋律推进、铺垫和情绪释放。',
    children: [
      {
        id: 'uplifting-trance',
        name: 'Uplifting Trance',
        description: '旋律明亮、情感强烈，高潮感突出。',
      },
      {
        id: 'psytrance',
        name: 'Psytrance',
        description: '高能重复节奏与迷幻音色。',
      },
    ],
  },
];

export const flattenGenres = (nodes: GenreNode[]): GenreNode[] => {
  const result: GenreNode[] = [];

  const dfs = (list: GenreNode[]) => {
    list.forEach((item) => {
      result.push(item);
      if (item.children?.length) {
        dfs(item.children);
      }
    });
  };

  dfs(nodes);
  return result;
};
