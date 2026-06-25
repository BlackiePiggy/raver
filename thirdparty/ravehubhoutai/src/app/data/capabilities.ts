import { media } from './media';

export type CapabilityMediaType = 'image' | 'video';

export interface Capability {
  id: string;
  title: string;
  description: string;
  accent: [string, string, string];
  glowColor: string;
  appScreen: string | null;
  appScreenType: CapabilityMediaType;
}

export const capabilitiesStorageKey = 'ravehub.capabilities.v1';
export const capabilitiesChangedEvent = 'ravehub:capabilities-changed';
const capabilitiesApiPath = '/api/ravehub-website/capabilities';

export const defaultCapabilities: Capability[] = [
  {
    id: '01',
    title: '全球电音活动指南',
    description: '汇集海内外各大电音节、艺人巡演、线下专场全量资讯，清晰呈现演出时间、场地、舞台排期与嘉宾阵容。同时收录各类电音曲风科普，不管是资深玩家还是入门新人，都能轻松找到心仪现场，一站式解锁全球电音现场动态。',
    accent: ['#06b6d4', '#14b8a6', '#10b981'],
    glowColor: 'rgba(6,182,212,0.4)',
    appScreen: media.capabilityScreens.events,
    appScreenType: 'image',
  },
  {
    id: '02',
    title: '专属电音成长档案',
    description: '记录每一次奔赴现场的美好瞬间，到场打卡自动留存观演足迹、喜爱 DJ 与参与场次。搭配专属成长体系，把每一场热爱都妥善珍藏，打造独属于你的专属电音履历，让音乐旅途有迹可循。',
    accent: ['#7c3aed', '#a855f7', '#ec4899'],
    glowColor: 'rgba(139,92,246,0.45)',
    appScreen: media.capabilityScreens.archive,
    appScreenType: 'image',
  },
  {
    id: '03',
    title: '同好结伴轻松同行',
    description: '搭建趣味小队社群，你可以组队相约出行，也能结识志同道合的玩伴。专为新手玩家匹配靠谱同行伙伴，告别独自奔赴的孤单，大家结伴打卡、互相照应，让每一次线下相聚都更安心、更欢乐。',
    accent: ['#ec4899', '#f43f5e', '#fb7185'],
    glowColor: 'rgba(236,72,153,0.4)',
    appScreen: media.capabilityScreens.team,
    appScreenType: 'image',
  },
  {
    id: '04',
    title: '电音兴趣分享社区',
    description: '这里是专属 Raver 的分享天地，随心发布现场实拍、观演心得、演出评价。聊聊喜欢的 DJ、分享出行攻略，和同好交流感受，用动态记录热爱，打造有温度的电音交流圈子。',
    accent: ['#f97316', '#f59e0b', '#facc15'],
    glowColor: 'rgba(249,115,22,0.4)',
    appScreen: media.capabilityScreens.community,
    appScreenType: 'video',
  },
  {
    id: '05',
    title: '全民共建资源宝库',
    description: '集结全体玩家力量，一起完善演出歌单、现场时刻表、场地攻略等实用内容。人人都能补充现场一手资料，共享干货、互通信息，慢慢沉淀出丰富又实用的电音资源库。',
    accent: ['#3b82f6', '#6366f1', '#8b5cf6'],
    glowColor: 'rgba(99,102,241,0.4)',
    appScreen: media.capabilityScreens.communitySets,
    appScreenType: 'video',
  },
  {
    id: '06',
    title: '直击艺人与主办方动态',
    description: '关注喜爱的 DJ、演出主办方，第一时间接收巡演预告、开票提醒与新鲜动态。近距离了解艺人幕后故事、活动最新消息，不错过每一场期待已久的演出。',
    accent: ['#a855f7', '#7c3aed', '#4f46e5'],
    glowColor: 'rgba(168,85,247,0.4)',
    appScreen: media.capabilityScreens.official,
    appScreenType: 'image',
  },
];

const isCapabilityMediaType = (value: unknown): value is CapabilityMediaType => (
  value === 'image' || value === 'video'
);

const asString = (value: unknown, fallback: string) => (
  typeof value === 'string' ? value : fallback
);

const normalizeAccent = (value: unknown, fallback: [string, string, string]) => {
  if (!Array.isArray(value)) {
    return fallback;
  }

  return [
    asString(value[0], fallback[0]),
    asString(value[1], fallback[1]),
    asString(value[2], fallback[2]),
  ] as [string, string, string];
};

export const normalizeCapabilities = (value: unknown): Capability[] => {
  if (!Array.isArray(value)) {
    return defaultCapabilities;
  }

  const normalized = value
    .map((item, index) => {
      if (!item || typeof item !== 'object') {
        return null;
      }

      const source = item as Partial<Capability>;
      const fallback = defaultCapabilities[index] ?? defaultCapabilities[0];
      const mediaType = isCapabilityMediaType(source.appScreenType) ? source.appScreenType : fallback.appScreenType;

      return {
        id: asString(source.id, String(index + 1).padStart(2, '0')),
        title: asString(source.title, fallback.title),
        description: asString(source.description, fallback.description),
        accent: normalizeAccent(source.accent, fallback.accent),
        glowColor: asString(source.glowColor, fallback.glowColor),
        appScreen: typeof source.appScreen === 'string' && source.appScreen.trim() ? source.appScreen : null,
        appScreenType: mediaType,
      };
    })
    .filter((item): item is Capability => item !== null);

  return normalized.length > 0 ? normalized : defaultCapabilities;
};

export const loadCapabilities = () => {
  return defaultCapabilities;
};

export const loadProjectCapabilities = async () => {
  if (typeof window === 'undefined') {
    return defaultCapabilities;
  }

  try {
    const url = `${import.meta.env.BASE_URL}capabilities.json`;
    const response = await fetch(url, { cache: 'no-store' });
    if (!response.ok) {
      return defaultCapabilities;
    }

    return normalizeCapabilities(await response.json());
  } catch {
    return defaultCapabilities;
  }
};

export const saveCapabilities = async (items: Capability[]) => {
  const normalized = normalizeCapabilities(items);
  const response = await fetch(capabilitiesApiPath, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(normalized),
  });

  if (!response.ok) {
    const detail = await response.text().catch(() => '');
    throw new Error(detail || '保存项目配置失败。');
  }

  window.localStorage.removeItem(capabilitiesStorageKey);
  window.dispatchEvent(new CustomEvent(capabilitiesChangedEvent));
  return normalized;
};

export const resetCapabilities = async () => {
  window.localStorage.removeItem(capabilitiesStorageKey);
  return saveCapabilities(defaultCapabilities);
};
