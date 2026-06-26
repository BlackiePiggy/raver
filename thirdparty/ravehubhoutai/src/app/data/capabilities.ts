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
    id: "01",
    title: "活动、DJ打卡陈列馆",
    description: "那些被低频震到起鸡皮疙瘩的夜晚，不该只躺在相册深处。每次看过的 DJ、冲过的音乐节、反复奔赴的舞台都会变成你的 Raver 履历，热爱有迹可循。",
    accent: [
      "#06b6d4",
      "#14b8a6",
      "#10b981"
    ],
    glowColor: "rgba(6,182,212,0.4)",
    appScreen: null,
    appScreenType: 'video'
  },
  {
    id: "02",
    title: "主办方主页与历史活动",
    description: "喜欢一个厂牌，就像认准一支会带你回家的声音。关注主办方后，过往阵容、历史活动和下一次开票都集中收好，不再错过那个“早知道我就去了”的夜晚。",
    accent: [
      "#7c3aed",
      "#a855f7",
      "#ec4899"
    ],
    glowColor: "rgba(139,92,246,0.45)",
    appScreen: null,
    appScreenType: 'video'
  },
  {
    id: "03",
    title: "探索活动",
    description: "别再把下一场派对交给算法随缘投喂，也别等群聊里半截海报救命。附近、国内、全球的活动主动浮出水面，让你从“刷到再说”变成“今晚去哪”。",
    accent: [
      "#ec4899",
      "#f43f5e",
      "#fb7185"
    ],
    glowColor: "rgba(236,72,153,0.4)",
    appScreen: null,
    appScreenType: 'video'
  },
  {
    id: "04",
    title: "DJ主页与行程",
    description: "真正喜欢一个 DJ，当然想知道 TA 下一站会把哪座城市点燃。主页把行程、历史演出和相关内容串起来，少一点到处翻动态，多一点准时出现在舞池。",
    accent: [
      "#f97316",
      "#f59e0b",
      "#facc15"
    ],
    glowColor: "rgba(249,115,22,0.4)",
    appScreen: null,
    appScreenType: 'video'
  },
  {
    id: "05",
    title: "路线图一键生成分享",
    description: "朋友问你今晚 Route？不用语音讲三分钟，也不用截图拼成毛毯。选好的舞台和时间一键生成路线图，直接甩图，队伍立刻知道下一脚该迈向哪里。",
    accent: [
      "#3b82f6",
      "#6366f1",
      "#8b5cf6"
    ],
    glowColor: "rgba(99,102,241,0.4)",
    appScreen: null,
    appScreenType: 'video'
  },
  {
    id: "06",
    title: "活动详情页",
    description: "现场没信号、朋友失联、舞台排期还在变，才是音乐节真正的隐藏关卡。活动详情支持离线缓存，阵容、时间、场地和注意事项都能稳稳留在手机里。",
    accent: [
      "#a855f7",
      "#7c3aed",
      "#4f46e5"
    ],
    glowColor: "rgba(168,85,247,0.4)",
    appScreen: null,
    appScreenType: 'video'
  },
  {
    id: "07",
    title: "现场视频与Tracklist共建",
    description: "Drop 那一下谁拍到了？最后一首到底是哪首？现场视频和 Tracklist 让大家一起补完记忆碎片，上传、校对、点赞，把一场演出变成全场共建的档案。",
    accent: [
      "#14b8a6",
      "#22d3ee",
      "#38bdf8"
    ],
    glowColor: "rgba(20,184,166,0.38)",
    appScreen: null,
    appScreenType: 'video'
  },
  {
    id: "08",
    title: "动态广场",
    description: "从入场手环到凌晨散场，从偶遇同好到被一段旋律击中，动态广场收留这些不想发给所有人、但一定想给同频的人看的现场碎片。",
    accent: [
      "#f43f5e",
      "#fb7185",
      "#f97316"
    ],
    glowColor: "rgba(244,63,94,0.38)",
    appScreen: null,
    appScreenType: 'video'
  },
  {
    id: "09",
    title: "活动直播聊天区",
    description: "站桩时的兴奋、转场时的迷路、等下一个 DJ 时的碎碎念，都可以丢进直播聊天区。谁在放、下一场去哪、哪个舞台炸，现场答案比攻略来得更快。",
    accent: [
      "#f59e0b",
      "#facc15",
      "#84cc16"
    ],
    glowColor: "rgba(245,158,11,0.36)",
    appScreen: null,
    appScreenType: 'video'
  },
  {
    id: "10",
    title: "线下活动地图实时位置",
    description: "小队最常见的问题不是音乐太大，是“你人呢”。实时地图把队友、舞台和现场点位放在一起，少一点人海捞人，多一点准时汇合继续蹦。",
    accent: [
      "#10b981",
      "#22c55e",
      "#84cc16"
    ],
    glowColor: "rgba(16,185,129,0.36)",
    appScreen: null,
    appScreenType: 'video'
  },
  {
    id: "11",
    title: "资讯功能",
    description: "官宣、改期、艺人动态、厂牌故事，不该散落在十个平台里等你考古。资讯功能把内容和活动、DJ、主办方关联起来，让电音新闻有上下文。",
    accent: [
      "#0ea5e9",
      "#38bdf8",
      "#67e8f9"
    ],
    glowColor: "rgba(14,165,233,0.36)",
    appScreen: null,
    appScreenType: 'video'
  },
  {
    id: "12",
    title: "电音流派风格直达",
    description: "听到陌生风格不用假装懂，也不用现场打开搜索狼狈补课。流派入口把声音脉络、代表艺人和相关活动连起来，从名字到听感，一路直达。",
    accent: [
      "#8b5cf6",
      "#a78bfa",
      "#c084fc"
    ],
    glowColor: "rgba(139,92,246,0.38)",
    appScreen: null,
    appScreenType: 'video'
  },
  {
    id: "13",
    title: "聚合搜索功能",
    description: "一个名字可能是 DJ、活动、厂牌，也可能藏在某条动态和资讯里。聚合搜索把相关内容一次捞起，不让灵感断在第十个搜索框前。",
    accent: [
      "#06b6d4",
      "#3b82f6",
      "#6366f1"
    ],
    glowColor: "rgba(59,130,246,0.38)",
    appScreen: null,
    appScreenType: 'video'
  },
  {
    id: "14",
    title: "消息中心",
    description: "开票提醒、搭子消息、共建审核、贡献反馈，都别再混进一堆无关推送里。消息中心只保留和你的电音生活有关的信号，重要节拍不错过。",
    accent: [
      "#ec4899",
      "#a855f7",
      "#6366f1"
    ],
    glowColor: "rgba(236,72,153,0.36)",
    appScreen: null,
    appScreenType: 'video'
  },
  {
    id: "15",
    title: "活动共建与上传",
    description: "电音场景太丰富，靠少数人永远追不上现场速度。把活动上传、资料补全和信息修正交给真正去现场的人，让数据库跟着社区一起长大。",
    accent: [
      "#22c55e",
      "#14b8a6",
      "#06b6d4"
    ],
    glowColor: "rgba(34,197,94,0.36)",
    appScreen: null,
    appScreenType: 'video'
  },
  {
    id: "16",
    title: "桌面小组件",
    description: "谁不想把下一场音乐节倒计时摆在桌面上？每次点亮屏幕都像听见远处舞台在热机，那份快出发的兴奋，提前住进日常。",
    accent: [
      "#fb7185",
      "#f97316",
      "#facc15"
    ],
    glowColor: "rgba(251,113,133,0.36)",
    appScreen: null,
    appScreenType: 'video'
  },
  {
    id: "17",
    title: "AI 运营后台管理系统",
    description: "面向运营方打造完善齐全的后台管理系统，将活动、艺人、内容、用户与数据运营集中在同一工作台，并结合 AI 能力辅助信息整理、内容生成、审核协同与运营决策，让复杂后台也能保持高效、清晰、好管理。",
    accent: [
      "#22d3ee",
      "#60a5fa",
      "#a78bfa"
    ],
    glowColor: "rgba(34,211,238,0.36)",
    appScreen: null,
    appScreenType: 'image'
  }
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
