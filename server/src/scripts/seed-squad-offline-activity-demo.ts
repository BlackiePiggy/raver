import { PrismaClient, Prisma } from '@prisma/client';

const prisma = new PrismaClient();

type Coordinate = {
  latitude: number;
  longitude: number;
};

const DEFAULT_SQUAD_NAME = '雷公电母';
const DEFAULT_PARTICIPANT_COUNT = 8;
const STAGE_OFFSETS_METERS = [
  { name: '主舞台', north: 0, east: 0 },
  { name: '低音舞台', north: 78, east: -52 },
  { name: '科技舞台', north: -64, east: 68 },
  { name: '日出舞台', north: 118, east: 96 },
];
const USER_NAMES = ['阿澈', 'Mika', '小北', 'Echo', 'Nina', 'Leo', 'Rin', 'Jules'];

function argValue(name: string): string | null {
  const prefix = `--${name}=`;
  const item = process.argv.find((value) => value.startsWith(prefix));
  return item ? item.slice(prefix.length).trim() : null;
}

function numericArg(name: string): number | null {
  const raw = argValue(name);
  if (!raw) return null;
  const parsed = Number(raw);
  return Number.isFinite(parsed) ? parsed : null;
}

function readJsonNumber(value: unknown, keys: string[]): number | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  let current: unknown = value;
  for (const key of keys) {
    if (!current || typeof current !== 'object' || Array.isArray(current)) return null;
    current = (current as Record<string, unknown>)[key];
  }
  return typeof current === 'number' && Number.isFinite(current) ? current : null;
}

function resolveEventCoordinate(event: {
  latitude?: Prisma.Decimal | null;
  longitude?: Prisma.Decimal | null;
  locationPoint?: Prisma.JsonValue | null;
  manualLocation?: Prisma.JsonValue | null;
} | null | undefined): Coordinate | null {
  if (!event) return null;
  const lat = event.latitude === null || event.latitude === undefined ? null : Number(event.latitude);
  const lng = event.longitude === null || event.longitude === undefined ? null : Number(event.longitude);
  if (lat !== null && lng !== null && Number.isFinite(lat) && Number.isFinite(lng)) {
    return { latitude: lat, longitude: lng };
  }

  const pointLat = readJsonNumber(event.locationPoint, ['location', 'lat']);
  const pointLng = readJsonNumber(event.locationPoint, ['location', 'lng']);
  if (pointLat !== null && pointLng !== null) return { latitude: pointLat, longitude: pointLng };

  const manualLat = readJsonNumber(event.manualLocation, ['coordinate', 'lat'])
    ?? readJsonNumber(event.manualLocation, ['location', 'lat']);
  const manualLng = readJsonNumber(event.manualLocation, ['coordinate', 'lng'])
    ?? readJsonNumber(event.manualLocation, ['location', 'lng']);
  if (manualLat !== null && manualLng !== null) return { latitude: manualLat, longitude: manualLng };

  return null;
}

function offsetCoordinate(center: Coordinate, northMeters: number, eastMeters: number): Coordinate {
  const latitude = center.latitude + northMeters / 111_320;
  const longitude = center.longitude + eastMeters / (111_320 * Math.cos(center.latitude * Math.PI / 180));
  return { latitude, longitude };
}

function userAvatar(seed: string): string {
  return `https://api.dicebear.com/9.x/adventurer-neutral/png?seed=${encodeURIComponent(seed)}&backgroundType=gradientLinear`;
}

async function ensureDemoUser(index: number) {
  const username = `offline_demo_${String(index + 1).padStart(2, '0')}`;
  return prisma.user.upsert({
    where: { username },
    update: {
      displayName: USER_NAMES[index] ?? `Demo ${index + 1}`,
      avatarUrl: userAvatar(username),
      isActive: true,
    },
    create: {
      username,
      email: `${username}@example.test`,
      passwordHash: 'offline-demo-user',
      displayName: USER_NAMES[index] ?? `Demo ${index + 1}`,
      displayNameNormalized: username,
      displayNameStatus: 'approved',
      avatarUrl: userAvatar(username),
      avatarStatus: 'approved',
      isActive: true,
    },
    select: { id: true, username: true, displayName: true },
  });
}

async function main() {
  const squadName = argValue('squad') || DEFAULT_SQUAD_NAME;
  const participantCount = Math.max(1, Math.min(numericArg('count') ?? DEFAULT_PARTICIPANT_COUNT, 24));
  const explicitLat = numericArg('lat');
  const explicitLng = numericArg('lng');

  const squad = await prisma.squad.findFirst({
    where: { name: squadName },
    include: {
      members: {
        include: { user: { select: { id: true, username: true, displayName: true } } },
        orderBy: [{ role: 'asc' }, { joinedAt: 'asc' }],
      },
    },
  });

  if (!squad) {
    throw new Error(`Squad not found: ${squadName}`);
  }

  let activity = await prisma.squadOfflineActivity.findFirst({
    where: { squadId: squad.id, status: 'active', endedAt: null },
    include: { event: true },
    orderBy: { startedAt: 'desc' },
  });

  if (!activity) {
    activity = await prisma.squadOfflineActivity.create({
      data: {
        squadId: squad.id,
        createdById: squad.leaderId,
        title: '线下活动模拟',
        participants: { create: { userId: squad.leaderId } },
      },
      include: { event: true },
    });
  }

  const center = explicitLat !== null && explicitLng !== null
    ? { latitude: explicitLat, longitude: explicitLng }
    : resolveEventCoordinate(activity.event);

  if (!center) {
    throw new Error('No event coordinate found. Bind an event with coordinates or pass --lat=... --lng=...');
  }

  const existingMembers = squad.members.map((member) => member.user);
  const users = [...existingMembers];
  for (let index = users.length; index < participantCount; index += 1) {
    const demoUser = await ensureDemoUser(index);
    await prisma.squadMember.upsert({
      where: { squadId_userId: { squadId: squad.id, userId: demoUser.id } },
      update: {},
      create: {
        squadId: squad.id,
        userId: demoUser.id,
        role: 'member',
        nickname: demoUser.displayName,
      },
    });
    users.push(demoUser);
  }

  const selectedUsers = users.slice(0, participantCount);
  const now = new Date();
  await prisma.$transaction(async (tx) => {
    for (const [index, user] of selectedUsers.entries()) {
      const stage = STAGE_OFFSETS_METERS[index % STAGE_OFFSETS_METERS.length];
      const jitterNorth = ((index * 17) % 23) - 11;
      const jitterEast = ((index * 13) % 19) - 9;
      const coordinate = offsetCoordinate(center, stage.north + jitterNorth, stage.east + jitterEast);
      const capturedAt = new Date(now.getTime() - (selectedUsers.length - index) * 12_000);

      await tx.squadOfflineActivityParticipant.upsert({
        where: { activityId_userId: { activityId: activity.id, userId: user.id } },
        update: {
          leftAt: null,
          lastLocationAt: capturedAt,
          isInRestroom: false,
          isBuyingDrink: false,
        },
        create: {
          activityId: activity.id,
          userId: user.id,
          joinedAt: new Date(now.getTime() - 18 * 60_000 + index * 20_000),
          lastLocationAt: capturedAt,
        },
      });

      await tx.squadOfflineActivityLocation.create({
        data: {
          activityId: activity.id,
          userId: user.id,
          latitude: new Prisma.Decimal(coordinate.latitude.toFixed(8)),
          longitude: new Prisma.Decimal(coordinate.longitude.toFixed(8)),
          accuracy: 8 + (index % 4) * 3,
          capturedAt,
        },
      });
    }
  });

  console.log('[seed-squad-offline-activity-demo] done');
  console.log({
    squad: squad.name,
    squadId: squad.id,
    activityId: activity.id,
    center,
    participants: selectedUsers.map((user, index) => ({
      user: user.displayName || user.username,
      stage: STAGE_OFFSETS_METERS[index % STAGE_OFFSETS_METERS.length].name,
    })),
  });
}

main()
  .catch((error) => {
    console.error('[seed-squad-offline-activity-demo] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
