import { PrismaClient, Prisma } from '@prisma/client';

const prisma = new PrismaClient();

type SeedAsset = {
  code: string;
  type: string;
  name: string;
  description: string;
  source: string;
  themeTags: string[];
  previewImageUrl: string;
  renderPayload: Prisma.InputJsonObject;
};

const assetBaseURL = process.env.VIRTUAL_ASSET_SEED_BASE_URL || 'https://assets.raver.example/virtual-assets';

const assetURL = (code: string, file = 'preview.png'): string => `${assetBaseURL}/${code}/${file}`;

const avatarFramePalettes = [
  ['#22D3EE', '#2563EB'],
  ['#FB7185', '#F97316'],
  ['#A78BFA', '#EC4899'],
  ['#34D399', '#14B8A6'],
  ['#FACC15', '#F59E0B'],
  ['#60A5FA', '#818CF8'],
  ['#F472B6', '#FB7185'],
  ['#4ADE80', '#A3E635'],
  ['#38BDF8', '#06B6D4'],
  ['#F87171', '#C084FC'],
];

const profileBadgeThemes = [
  { letter: 'R', shape: 'circle', colors: ['#111827', '#22D3EE'], title: 'Raver' },
  { letter: 'D', shape: 'diamond', colors: ['#7C2D12', '#FB923C'], title: 'DJ' },
  { letter: 'F', shape: 'hex', colors: ['#1E1B4B', '#A78BFA'], title: 'Festival' },
  { letter: 'L', shape: 'ticket', colors: ['#064E3B', '#34D399'], title: 'Label' },
  { letter: 'B', shape: 'shield', colors: ['#701A75', '#F472B6'], title: 'Bass' },
  { letter: 'T', shape: 'slant', colors: ['#172554', '#60A5FA'], title: 'Techno' },
  { letter: 'H', shape: 'star', colors: ['#78350F', '#FACC15'], title: 'House' },
  { letter: 'N', shape: 'capsule', colors: ['#164E63', '#67E8F9'], title: 'Night' },
  { letter: 'V', shape: 'octagon', colors: ['#4C1D95', '#C084FC'], title: 'VIP' },
  { letter: 'X', shape: 'burst', colors: ['#7F1D1D', '#FB7185'], title: 'X' },
];

const avatarFrames: SeedAsset[] = Array.from({ length: 10 }, (_, index) => {
  const number = index + 1;
  const code = `avatar_frame_v1_${String(number).padStart(2, '0')}`;
  const [primary, secondary] = avatarFramePalettes[index];
  return {
    code,
    type: 'avatar_frame',
    name: `发光头像框 ${number}`,
    description: 'V1 代码绘制发光头像框，用于个人主页和聊天头像展示。',
    source: number <= 3 ? 'default' : number <= 6 ? 'membership' : 'event_reward',
    themeTags: number <= 4 ? ['festival'] : number <= 7 ? ['member'] : ['squad'],
    previewImageUrl: assetURL(code),
    renderPayload: {
      renderMode: 'code_glow',
      frameShape: 'circle',
      frameInsets: { top: -5, left: -5, bottom: -5, right: -5 },
      minAvatarSize: 32,
      supportsCircularAvatar: true,
      renderPriority: number,
      gradientColors: [primary, secondary],
      glowColorHex: primary,
      glowRadius: 9 + number,
      ringWidth: 2.6 + (number % 3) * 0.5,
      innerRingColorHex: 'rgba(255,255,255,0.72)',
      darkVariant: {
        innerRingColorHex: 'rgba(255,255,255,0.42)',
      },
    },
  };
});

const profileBadges: SeedAsset[] = Array.from({ length: 10 }, (_, index) => {
  const number = index + 1;
  const code = `profile_badge_v1_${String(number).padStart(2, '0')}`;
  const theme = profileBadgeThemes[index];
  return {
    code,
    type: 'profile_badge',
    name: `${theme.title} 徽章`,
    description: 'V1 代码绘制字母徽章，个人主页 Hero 区最多展示 5 个。',
    source: number <= 2 ? 'default' : number <= 5 ? 'event_reward' : 'membership',
    themeTags: number <= 3 ? ['festival'] : number <= 6 ? ['dj'] : ['label'],
    previewImageUrl: assetURL(code),
    renderPayload: {
      renderMode: 'letter_badge',
      letter: theme.letter,
      title: theme.title,
      badgeShape: theme.shape,
      displayMode: number % 3 === 0 ? 'icon_text' : number % 2 === 0 ? 'pill' : 'icon',
      gradientColors: theme.colors,
      backgroundColorHex: theme.colors[0],
      textColorHex: '#FFFFFF',
      borderColorHex: 'rgba(255,255,255,0.42)',
      glowColorHex: theme.colors[1],
      maxDisplayContext: {
        profileHero: true,
        chatNickname: number <= 4,
        list: number <= 6,
      },
      lightBackgroundColorHex: theme.colors[1],
      darkBackgroundColorHex: theme.colors[0],
    },
  };
});

const chatBubbleSkins: SeedAsset[] = Array.from({ length: 10 }, (_, index) => {
  const number = index + 1;
  const code = `chat_bubble_skin_v1_${String(number).padStart(2, '0')}`;
  const hue = 190 + number * 13;
  return {
    code,
    type: 'chat_bubble_skin',
    name: `消息气泡 ${number}`,
    description: 'V1 静态消息气泡皮肤，支持文字颜色和可读性 fallback。',
    source: number <= 4 ? 'default' : number <= 7 ? 'membership' : 'event_reward',
    themeTags: number <= 3 ? ['festival'] : number <= 6 ? ['dj'] : ['label'],
    previewImageUrl: assetURL(code),
    renderPayload: {
      bubbleStyle: 'gradient',
      gradientColors: [`hsl(${hue}, 82%, 44%)`, `hsl(${hue + 34}, 78%, 38%)`],
      textColorHex: '#FFFFFF',
      fallbackTextColorHex: '#FFFFFF',
      borderColorHex: 'rgba(255,255,255,0.18)',
      cornerProfile: 'demo_aligned_cluster',
      incomingSupported: false,
      outgoingSupported: true,
      lightVariant: {
        textColorHex: '#111827',
        borderColorHex: 'rgba(17,24,39,0.12)',
      },
    },
  };
});

const titleMedals: SeedAsset[] = Array.from({ length: 10 }, (_, index) => {
  const number = index + 1;
  const code = `title_medal_v1_${String(number).padStart(2, '0')}`;
  const shapes = ['capsule', 'ticket', 'ribbon', 'hex', 'slant', 'neon_plate'];
  return {
    code,
    type: 'title_medal',
    name: `称号勋章 ${number}`,
    description: 'V1 系统预置称号，用户不可自定义文案。',
    source: number <= 3 ? 'default' : number <= 6 ? 'membership' : 'event_reward',
    themeTags: number <= 3 ? ['festival'] : number <= 6 ? ['squad'] : ['label'],
    previewImageUrl: assetURL(code),
    renderPayload: {
      labelShape: shapes[index % shapes.length],
      text: ['夜航员', '前排玩家', '低频收藏家', '舞池常客', '厂牌猎人', '巡演雷达', '小队核心', '票根守护者', 'Festival Mode', 'Label Insider'][index],
      textColorHex: '#FFFFFF',
      backgroundColorHex: '#151923',
      gradientColors: ['#06B6D4', '#3B82F6'],
      borderColorHex: 'rgba(255,255,255,0.22)',
      iconURL: assetURL(code, 'icon.png'),
      maxTextLength: 16,
      fixedWidth: 88,
      compactFixedWidth: 74,
      lightVariant: {
        textColorHex: '#111827',
        backgroundColorHex: '#EEF6FF',
      },
    },
  };
});

const assets: SeedAsset[] = [
  ...avatarFrames,
  ...profileBadges,
  ...chatBubbleSkins,
  ...titleMedals,
];

const defaultDevelopmentGrantUsers = ['blackie', 'h3y2', 'leshanlijiayu', 'uploadtester'];
const grantUsersEnv = process.env.VIRTUAL_ASSET_SEED_GRANT_USERS;
const shouldGrantDefaultDevelopmentUsers = process.env.NODE_ENV !== 'production' && grantUsersEnv === undefined;

const parseGrantUserSelectors = (value: string | undefined): string[] => {
  if (value === undefined) {
    return shouldGrantDefaultDevelopmentUsers ? defaultDevelopmentGrantUsers : [];
  }

  const trimmed = value.trim();
  if (!trimmed || trimmed.toLowerCase() === 'none') {
    return [];
  }

  return trimmed
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
};

const equipLimitByType: Record<string, number> = {
  avatar_frame: 1,
  profile_badge: 3,
  chat_bubble_skin: 1,
  title_medal: 1,
};

const defaultEquippedAssets = (seededAssets: { id: string; code: string; type: string }[]) => {
  return Object.entries(equipLimitByType).flatMap(([type, limit]) => {
    const assetIds = seededAssets
      .filter((asset) => asset.type === type)
      .sort((left, right) => left.code.localeCompare(right.code))
      .slice(0, limit)
      .map((asset) => asset.id);

    return assetIds.length > 0 ? [{ assetType: type, assetIds }] : [];
  });
};

async function main(): Promise<void> {
  const seededAssets: { id: string; code: string; type: string }[] = [];

  for (const asset of assets) {
    const seededAsset = await prisma.virtualAssetDefinition.upsert({
      where: { code: asset.code },
      create: {
        code: asset.code,
        type: asset.type,
        name: asset.name,
        description: asset.description,
        status: 'active',
        renderPayload: asset.renderPayload,
        previewImageUrl: asset.previewImageUrl,
        source: asset.source,
        themeTags: asset.themeTags,
      },
      update: {
        type: asset.type,
        name: asset.name,
        description: asset.description,
        status: 'active',
        renderPayload: asset.renderPayload,
        previewImageUrl: asset.previewImageUrl,
        source: asset.source,
        themeTags: asset.themeTags,
      },
    });

    seededAssets.push({
      id: seededAsset.id,
      code: seededAsset.code,
      type: seededAsset.type,
    });
  }

  console.log(`Seeded ${assets.length} virtual assets.`);

  const grantUserSelectors = parseGrantUserSelectors(grantUsersEnv);
  if (grantUserSelectors.length === 0) {
    console.log('Skipped virtual asset inventory grants.');
    return;
  }

  const grantAllUsers = grantUserSelectors.some((selector) => selector.toLowerCase() === 'all');
  const grantUsers = await prisma.user.findMany({
    where: grantAllUsers
      ? {}
      : {
          OR: grantUserSelectors.flatMap((selector) => [
            { id: selector },
            { username: selector },
            { email: selector },
            { displayName: selector },
          ]),
        },
    select: {
      id: true,
      username: true,
      email: true,
      displayName: true,
    },
  });

  if (grantUsers.length === 0) {
    console.log(`No users matched virtual asset grant selectors: ${grantUserSelectors.join(', ')}`);
    return;
  }

  const equips = defaultEquippedAssets(seededAssets);
  for (const user of grantUsers) {
    await prisma.$transaction([
      ...seededAssets.map((asset) =>
        prisma.userVirtualAsset.upsert({
          where: {
            userId_assetId: {
              userId: user.id,
              assetId: asset.id,
            },
          },
          create: {
            userId: user.id,
            assetId: asset.id,
            acquisitionSource: 'seed',
            metadata: {
              seedCode: asset.code,
              grantedBy: 'seed-virtual-assets',
            },
          },
          update: {
            status: 'active',
            acquisitionSource: 'seed',
            metadata: {
              seedCode: asset.code,
              grantedBy: 'seed-virtual-assets',
            },
          },
        })
      ),
      ...equips.map((equip) =>
        prisma.userVirtualAssetEquip.upsert({
          where: {
            userId_assetType: {
              userId: user.id,
              assetType: equip.assetType,
            },
          },
          create: {
            userId: user.id,
            assetType: equip.assetType,
            assetIds: equip.assetIds,
          },
          update: {
            assetIds: equip.assetIds,
          },
        })
      ),
    ]);
  }

  console.log(
    `Granted ${seededAssets.length} virtual assets and default equips to ${grantUsers.length} user(s): ${grantUsers
      .map((user) => user.username || user.email || user.displayName || user.id)
      .join(', ')}.`
  );
}

main()
  .catch((error) => {
    console.error('Failed to seed virtual assets:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
