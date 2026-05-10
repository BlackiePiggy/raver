import { Prisma, PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export const VIRTUAL_ASSET_TYPES = [
  'avatar_frame',
  'profile_badge',
  'chat_bubble_skin',
  'title_medal',
] as const;

export type VirtualAssetType = (typeof VIRTUAL_ASSET_TYPES)[number];

const EQUIP_LIMITS: Record<VirtualAssetType, number> = {
  avatar_frame: 1,
  profile_badge: 5,
  chat_bubble_skin: 1,
  title_medal: 1,
};

const ACTIVE_DEFINITION_STATUS = 'active';
const ACTIVE_OWNERSHIP_STATUS = 'active';

export class VirtualAssetError extends Error {
  statusCode: number;

  constructor(message: string, statusCode = 400) {
    super(message);
    this.name = 'VirtualAssetError';
    this.statusCode = statusCode;
  }
}

type AssetDefinitionRow = Awaited<ReturnType<typeof prisma.virtualAssetDefinition.findFirst>>;
type UserAssetRow = Awaited<ReturnType<typeof prisma.userVirtualAsset.findFirst>>;

type UserAssetWithDefinition = NonNullable<UserAssetRow> & {
  asset: NonNullable<AssetDefinitionRow>;
};

type EquipRow = Awaited<ReturnType<typeof prisma.userVirtualAssetEquip.findFirst>>;

type CatalogFilters = {
  type?: string;
  includeHidden?: boolean;
};

type GrantInput = {
  userId: string;
  assetId?: string;
  assetCode?: string;
  acquisitionSource?: string;
  expiresAt?: string | null;
  metadata?: Prisma.InputJsonValue;
};

const isVirtualAssetType = (value: string): value is VirtualAssetType => {
  return (VIRTUAL_ASSET_TYPES as readonly string[]).includes(value);
};

const parseAssetType = (value: string): VirtualAssetType => {
  const normalized = String(value || '').trim();
  if (!isVirtualAssetType(normalized)) {
    throw new VirtualAssetError(`Unsupported virtual asset type: ${value}`, 400);
  }
  return normalized;
};

const isDefinitionVisible = (asset: NonNullable<AssetDefinitionRow>, now = new Date()): boolean => {
  if (asset.status !== ACTIVE_DEFINITION_STATUS) return false;
  if (asset.startsAt && asset.startsAt > now) return false;
  if (asset.endsAt && asset.endsAt <= now) return false;
  return true;
};

const isOwnershipUsable = (item: UserAssetWithDefinition, now = new Date()): boolean => {
  if (item.status !== ACTIVE_OWNERSHIP_STATUS) return false;
  if (item.expiresAt && item.expiresAt <= now) return false;
  return isDefinitionVisible(item.asset, now);
};

const serializeDate = (value: Date | null | undefined): string | null => {
  return value ? value.toISOString() : null;
};

const serializeAssetDefinition = (asset: NonNullable<AssetDefinitionRow>) => ({
  id: asset.id,
  code: asset.code,
  type: asset.type,
  name: asset.name,
  description: asset.description,
  status: asset.status,
  renderPayload: asset.renderPayload,
  previewImageURL: asset.previewImageUrl,
  source: asset.source,
  themeTags: asset.themeTags,
  startsAt: serializeDate(asset.startsAt),
  endsAt: serializeDate(asset.endsAt),
  createdAt: asset.createdAt.toISOString(),
  updatedAt: asset.updatedAt.toISOString(),
});

const serializeOwnership = (item: UserAssetWithDefinition, now = new Date()) => ({
  id: item.id,
  userId: item.userId,
  assetId: item.assetId,
  acquisitionSource: item.acquisitionSource,
  status: item.status,
  acquiredAt: item.acquiredAt.toISOString(),
  expiresAt: serializeDate(item.expiresAt),
  metadata: item.metadata,
  isUsable: isOwnershipUsable(item, now),
  asset: serializeAssetDefinition(item.asset),
});

const serializeEquip = (equip: NonNullable<EquipRow>) => ({
  userId: equip.userId,
  assetType: equip.assetType,
  assetIds: equip.assetIds,
  updatedAt: equip.updatedAt.toISOString(),
});

const latestEquipVersion = (equips: NonNullable<EquipRow>[]): number => {
  if (equips.length === 0) return 1;
  return Math.max(...equips.map((item) => item.updatedAt.getTime()));
};

export const virtualAssetService = {
  async listCatalog(filters: CatalogFilters = {}) {
    const where: Prisma.VirtualAssetDefinitionWhereInput = {};
    if (filters.type) {
      where.type = parseAssetType(filters.type);
    }
    if (!filters.includeHidden) {
      const now = new Date();
      where.status = ACTIVE_DEFINITION_STATUS;
      where.AND = [
        { OR: [{ startsAt: null }, { startsAt: { lte: now } }] },
        { OR: [{ endsAt: null }, { endsAt: { gt: now } }] },
      ];
    }

    const assets = await prisma.virtualAssetDefinition.findMany({
      where,
      orderBy: [{ type: 'asc' }, { createdAt: 'asc' }],
    });

    return {
      assets: assets.map(serializeAssetDefinition),
    };
  },

  async getMyAssets(userId: string) {
    const now = new Date();
    const [inventory, equips, appearance] = await Promise.all([
      prisma.userVirtualAsset.findMany({
        where: { userId },
        include: { asset: true },
        orderBy: [{ acquiredAt: 'desc' }],
      }),
      prisma.userVirtualAssetEquip.findMany({
        where: { userId },
        orderBy: [{ assetType: 'asc' }],
      }),
      this.getAppearance(userId),
    ]);

    return {
      inventory: inventory.map((item) => serializeOwnership(item, now)),
      equips: equips.map(serializeEquip),
      appearance,
    };
  },

  async getAppearance(userId: string) {
    const now = new Date();
    const equips = await prisma.userVirtualAssetEquip.findMany({
      where: { userId },
    });
    const equippedAssetIds = Array.from(new Set(equips.flatMap((item) => item.assetIds)));

    if (equippedAssetIds.length === 0) {
      return {
        userId,
        avatarFrame: null,
        titleMedal: null,
        profileBadges: [],
        chatBubbleSkin: null,
        version: latestEquipVersion(equips),
      };
    }

    const ownedAssets = await prisma.userVirtualAsset.findMany({
      where: {
        userId,
        assetId: { in: equippedAssetIds },
      },
      include: { asset: true },
    });
    const usableById = new Map(
      ownedAssets
        .filter((item) => isOwnershipUsable(item, now))
        .map((item) => [item.assetId, serializeAssetDefinition(item.asset)])
    );
    const equipByType = new Map(equips.map((item) => [item.assetType, item.assetIds]));
    const firstAssetForType = (type: VirtualAssetType) => {
      const assetIds = equipByType.get(type) ?? [];
      const asset = assetIds.map((assetId) => usableById.get(assetId)).find(Boolean);
      return asset ?? null;
    };

    const badgeIds = equipByType.get('profile_badge') ?? [];
    const profileBadges = badgeIds
      .map((assetId) => usableById.get(assetId))
      .filter((asset): asset is NonNullable<ReturnType<typeof usableById.get>> => Boolean(asset))
      .slice(0, EQUIP_LIMITS.profile_badge);

    return {
      userId,
      avatarFrame: firstAssetForType('avatar_frame'),
      titleMedal: firstAssetForType('title_medal'),
      profileBadges,
      chatBubbleSkin: firstAssetForType('chat_bubble_skin'),
      version: latestEquipVersion(equips),
    };
  },

  async updateEquip(userId: string, rawAssetType: string, rawAssetIds: string[]) {
    const assetType = parseAssetType(rawAssetType);
    const assetIds = Array.from(new Set(rawAssetIds.map((item) => String(item || '').trim()).filter(Boolean)));
    const limit = EQUIP_LIMITS[assetType];

    if (assetIds.length > limit) {
      throw new VirtualAssetError(`${assetType} can equip at most ${limit} asset(s)`, 400);
    }

    if (assetIds.length > 0) {
      const now = new Date();
      const ownedAssets = await prisma.userVirtualAsset.findMany({
        where: {
          userId,
          assetId: { in: assetIds },
        },
        include: { asset: true },
      });
      const ownedById = new Map(ownedAssets.map((item) => [item.assetId, item]));

      for (const assetId of assetIds) {
        const owned = ownedById.get(assetId);
        if (!owned) {
          throw new VirtualAssetError(`Asset is not owned: ${assetId}`, 403);
        }
        if (owned.asset.type !== assetType) {
          throw new VirtualAssetError(`Asset type mismatch: ${assetId}`, 400);
        }
        if (!isOwnershipUsable(owned, now)) {
          throw new VirtualAssetError(`Asset is not usable: ${assetId}`, 400);
        }
      }
    }

    const equip = await prisma.userVirtualAssetEquip.upsert({
      where: {
        userId_assetType: {
          userId,
          assetType,
        },
      },
      create: {
        userId,
        assetType,
        assetIds,
      },
      update: {
        assetIds,
      },
    });

    return {
      equip: serializeEquip(equip),
      appearance: await this.getAppearance(userId),
    };
  },

  async grantAsset(input: GrantInput) {
    if (!input.userId || (!input.assetId && !input.assetCode)) {
      throw new VirtualAssetError('userId and assetId or assetCode are required', 400);
    }

    const asset = await prisma.virtualAssetDefinition.findFirst({
      where: input.assetId ? { id: input.assetId } : { code: input.assetCode },
    });
    if (!asset) {
      throw new VirtualAssetError('Asset not found', 404);
    }

    const user = await prisma.user.findUnique({
      where: { id: input.userId },
      select: { id: true },
    });
    if (!user) {
      throw new VirtualAssetError('User not found', 404);
    }

    const expiresAt = input.expiresAt ? new Date(input.expiresAt) : null;
    if (expiresAt && Number.isNaN(expiresAt.getTime())) {
      throw new VirtualAssetError('expiresAt is invalid', 400);
    }

    const ownership = await prisma.userVirtualAsset.upsert({
      where: {
        userId_assetId: {
          userId: input.userId,
          assetId: asset.id,
        },
      },
      create: {
        userId: input.userId,
        assetId: asset.id,
        acquisitionSource: input.acquisitionSource || 'admin_grant',
        expiresAt,
        metadata: input.metadata ?? undefined,
      },
      update: {
        status: ACTIVE_OWNERSHIP_STATUS,
        acquisitionSource: input.acquisitionSource || 'admin_grant',
        expiresAt,
        metadata: input.metadata ?? undefined,
      },
      include: { asset: true },
    });

    return serializeOwnership(ownership);
  },
};
